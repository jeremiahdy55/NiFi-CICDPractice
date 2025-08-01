pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'github_credentials'
        SSH_KEY         = 'nifi_ssh_key'
        REPO_URL        = 'https://github.com/apache/nifi.git'
        AWS_REGION      = 'us-west-2' // hard-coded, make sure this matches whatever is in terraform scripts
    }

    // **tools** must be configured in Jenkins-Tools
    tools {
        maven 'maven3.9.3' 
    }

    stages {
        
        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM', 
                    branches: [[name: 'refs/tags/rel/nifi-1.26.0']], 
                    userRemoteConfigs: [[
                        url: "${env.REPO_URL}",
                        credentialsId: "${env.GIT_CREDENTIALS}"
                    ]]
                ])
            }
        }


        stage('Build nifi-assembly') {
            steps {
                dir('nifi-assembly') {
                    sh 'mvn clean install -DskipTests'
                    sh 'zip -r ../nifi-1.26.0-bin.zip target/nifi-1.26.0-bin'
                }
            }
        }

        stage('Copy artifact to NiFi server via SFTP') {
            steps {
                sshagent([env.SSH_KEY]) {
                    script {
                        sh '''
                            # Fetch S3_BUCKET Address
                            export S3_BUCKET=$(grep '^S3_BUCKET=' /etc/environment | cut -d '=' -f2)
                            
                            # Fetch NiFi EC2 Instance's public IP from S3
                            aws s3 cp s3://$S3_BUCKET/nifi_ip.txt nifi_ip.txt
                            NIFI_IP=$(cat nifi_ip.txt)

                            # Transfer the zip file to the NiFi EC2 instance using SCP (no -i needed)
                            scp -o StrictHostKeyChecking=no \
                                nifi-assembly/target/nifi-1.26.0-bin.zip \
                                ubuntu@$NIFI_IP:/home/ubuntu/

                            # SSH into the EC2 instance and unzip
                            ssh -o StrictHostKeyChecking=no ubuntu@$NIFI_IP << EOF
                                unzip -o /home/ubuntu/nifi-1.26.0-bin.zip -d /home/ubuntu/
                                echo "NiFi unzipped successfully."
EOF
                        '''
                    }
                }
            }
        }

    }

    post {
        success{
            echo 'Build success!'
        }
        failure{
            echo 'Build failure :('
        }
    }
}