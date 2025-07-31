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

    - name: Copy Jenkins key
      copy:
        src: "${KEY_PATH}"
        dest: /home/ubuntu/TF_NiFi_Server_KEY.pem
        owner: ubuntu
        mode: '0600'

    - name: Start Jenkins
      systemd:
        name: jenkins
        enabled: yes
        state: started

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
