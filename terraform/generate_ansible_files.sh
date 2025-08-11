#!/bin/bash

# Check if the ssh-key and nifi-version were given as arguments
# If either is missing, return the correct usage
KEY_PATH="$1"
NIFI_VERSION="$2"
if [ -z "$KEY_PATH" ] || [ -z "$NIFI_VERSION" ]; then
  echo "Usage: sh $0 <PATH TO PRIVATE KEY> <NIFI VERSION TO BUILD> "
  exit 1
fi

# Define subdirectory for Ansible files
ANSIBLE_DIR="./ansible"

# Create the directory if it doesn't exist
mkdir -p "$ANSIBLE_DIR"

# Get public IP from terraform output
JENKINS_PUBLIC_IP=$(terraform output -raw jenkins_public_ip)
NIFI_PUBLIC_IP=$(terraform output -raw nifi_public_ip)
NIFI_PRIVATE_IP=$(terraform output -raw nifi_private_ip)

# Generate inventory.ini
# ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
# ^^ disables the "Host not known, trust this source?" message
# ^^ i.e. trusts anything (only good for ephermal/known/internal environments)
cat <<EOF > "$ANSIBLE_DIR/inventory.ini"
[jenkins]
${JENKINS_PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${KEY_PATH} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[nifi]
${NIFI_PUBLIC_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${KEY_PATH} ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

# Generate configure_ec2instances.yml
cat <<EOF > "$ANSIBLE_DIR/configure_ec2instances.yml"
- name: Configure Jenkins
  hosts: jenkins
  become: true
  tasks:
    - name: Update and upgrade apt packages
      apt:
        update_cache: yes
        upgrade: dist

    - name: Install required packages
      apt:
        name:
          - openjdk-17-jdk
          - unzip
          - curl
          - gnupg
          - software-properties-common
          - zip
        state: present

    - name: Add Docker GPG apt Key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker APT repository
      apt_repository:
        repo: deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable
        state: present
        update_cache: yes

    - name: Install Docker CE
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
        state: present

    - name: Download AWS CLI installer
      get_url:
        url: https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
        dest: /tmp/awscliv2.zip
        mode: '0644'

    - name: Unzip AWS CLI installer
      unarchive:
        src: /tmp/awscliv2.zip
        dest: /tmp/
        remote_src: yes

    - name: Install AWS CLI
      command: sudo /tmp/aws/install
      args:
        creates: /usr/local/bin/aws

    - name: Clean up AWS CLI installer files
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /tmp/awscliv2.zip
        - /tmp/aws

    - name: Download latest kubectl binary
      get_url:
        url: "https://dl.k8s.io/release/{{ lookup('url', 'https://dl.k8s.io/release/stable.txt') }}/bin/linux/amd64/kubectl"
        dest: /usr/local/bin/kubectl
        mode: '0755'

    - name: Verify kubectl installation
      command: kubectl version --client

    - name: Download and save Jenkins GPG keyring
      get_url:
        url: https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
        dest: /usr/share/keyrings/jenkins-keyring.asc
        mode: '0644'

    - name: Add Jenkins repository
      apt_repository:
        repo: "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/"
        filename: jenkins
        state: present
        update_cache: yes

    - name: Install Jenkins
      apt:
        name: jenkins
        state: present
        update_cache: yes
      
    - name: Enable and start Docker service
      systemd:
        name: docker
        enabled: yes
        state: started

    - name: Add Jenkins user to docker group
      user:
        name: jenkins
        groups: docker
        append: yes

    - name: Enable and start Jenkins service
      systemd:
        name: jenkins
        enabled: yes
        state: started
      
    - name: Restart Jenkins to apply Docker group permissions
      systemd:
        name: jenkins
        state: restarted

- name: Configure NiFi
  hosts: nifi
  become: true
  tasks:
    - name: Install dependencies
      apt:
        name: "{{ item }}"
        state: present
        update_cache: yes
      loop:
        - openjdk-17-jdk
        - unzip
        - curl
EOF

# Generate start_nifi.yml
cat <<EOF > "$ANSIBLE_DIR/start_nifi.yml"
- name: Update NiFi properties and start NiFi
  hosts: nifi
  become: yes
  vars:
    nifi_release_name: "${NIFI_VERSION}"
    nifi_properties_file: /home/ubuntu/${NIFI_VERSION}/conf/nifi.properties
    nifi_start_file: /home/ubuntu/${NIFI_VERSION}/bin/nifi.sh
    nifi_private_IP: "${NIFI_PRIVATE_IP}"

  tasks:

    ### Comment out https host and port
    - name: Comment out nifi.web.https.host
      lineinfile:
        path: "{{ nifi_properties_file }}"
        regexp: '^nifi.web.https.host='
        line: '#nifi.web.https.host=127.0.0.1'
        backrefs: yes

    - name: Comment out nifi.web.https.port
      lineinfile:
        path: "{{ nifi_properties_file }}"
        regexp: '^nifi.web.https.port='
        line: '#nifi.web.https.port=8443'
        backrefs: yes
      

    ### Configure http host and port
    - name: Set nifi.web.http.host
      lineinfile:
        path: "{{ nifi_properties_file }}"
        regexp: '^nifi.web.http.host='
        line: 'nifi.web.http.host={{ nifi_private_IP }}'
        backrefs: yes

    - name: Set nifi.web.http.port
      lineinfile:
        path: "{{ nifi_properties_file }}"
        regexp: '^nifi.web.http.port='
        line: 'nifi.web.http.port=8443'
        backrefs: yes
    

    # Set nifi.remote.input.secure to false
    - name: Set nifi.remote.input.secure to false
      lineinfile:
        path: "{{ nifi_properties_file }}"
        regexp: '^nifi.remote.input.secure='
        line: 'nifi.remote.input.secure=false'
        backrefs: yes

    # Empty the given security properties
    - name: Clear specified NiFi security properties (make their values empty)
      loop:
        - nifi.security.keystore
        - nifi.security.truststore
        - nifi.security.keystoreType
        - nifi.security.keystorePasswd
        - nifi.security.keyPasswd
        - nifi.security.truststoreType
        - nifi.security.truststorePasswd
      ansible.builtin.lineinfile:
        path: "{{ nifi_properties_file }}"
        regexp: '^{{ item | regex_escape() }}='
        line: '{{ item }}='
        create: yes
        backrefs: yes

    # 4 Start NiFi service
    - name: Start NiFi Service
      shell: "{{ nifi_start_file }} start"
      args:
        chdir: "{{ nifi_start_file | dirname }}"
EOF

echo "Generated files:"
echo "  $ANSIBLE_DIR/inventory.ini"
echo "  $ANSIBLE_DIR/configure_ec2instances.yml"
echo "  $ANSIBLE_DIR/start_nifi.yml"
