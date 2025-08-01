#!/bin/bash

# Get private key path from argument
# Or return if not argument was given
KEY_PATH="$1"
if [ -z "$KEY_PATH" ]; then
  echo "Usage: sh $0 /path/to/private-key.pem"
  exit 1
fi

# Define subdirectory for Ansible files
ANSIBLE_DIR="./ansible"

# Create the directory if it doesn't exist
mkdir -p "$ANSIBLE_DIR"

# Get public IP from terraform output
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
NIFI_IP=$(terraform output -raw nifi_public_ip)

# Generate inventory.ini
cat <<EOF > "$ANSIBLE_DIR/inventory.ini"
[jenkins]
${JENKINS_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${KEY_PATH}

[nifi]
${NIFI_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${KEY_PATH}
EOF

# Generate configure_servers.yml
cat <<EOF > "$ANSIBLE_DIR/configure_servers.yml"
- name: Configure Jenkins
  hosts: jenkins
  become: true
  vars:
    KEY_PATH: "${KEY_PATH}"
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

    - name: Enable and start Jenkins service
      systemd:
        name: jenkins
        enabled: yes
        state: started

    - name: Copy Jenkins SSH private key
      copy:
        src: "{{ KEY_PATH }}"
        dest: /home/jenkins/TF_NiFi_Server_KEY.pem
        owner: ubuntu
        mode: '0600'


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

echo "Generated files:"
echo "  $ANSIBLE_DIR/inventory.ini"
echo "  $ANSIBLE_DIR/configure_servers.yml"
