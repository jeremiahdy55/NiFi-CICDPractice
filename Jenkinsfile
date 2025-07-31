pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'github_credentials'
        // SSH_KEY         = 'nifi_ssh_key'
        REPO_URL        = 'https://github.com/apache/nifi.git'
        AWS_REGION      = 'us-west-2' // hard-coded, make sure this matches whatever is in terraform scripts
    }

    // **tools** must be setup in Jenkins-Tools config
    tools {
        maven 'maven3.9.3' 
        // jdk 'jdk17'
    }

    stages {
        // stage('Load S3 bucket name from /etc/environment') {
        //     steps {
        //         script {
        //             def s3Bucket = sh(script: "grep '^S3_BUCKET=' /etc/environment | cut -d '=' -f2", returnStdout: true).trim()
        //             env.S3_BUCKET = s3Bucket
        //             echo "Loaded S3_BUCKET from /etc/environment: ${env.S3_BUCKET}"
        //         }
        //     }
        // }
        
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
                script {
                    sh '''
                        # Fetch S3_BUCKET Address
                        export S3_BUCKET=$(grep '^S3_BUCKET=' /etc/environment | cut -d '=' -f2)
                        
                        # Fetch NiFi EC2 Instance's public IP from S3
                        aws s3 cp s3://$S3_BUCKET/nifi_ip.txt nifi_ip.txt
                        NIFI_IP=$(cat nifi_ip.txt)

                        # Prepare the private key
                        KEY_PATH="/home/ubuntu/TF_NiFi_Server_KEY.pem"
                        chmod 400 $KEY_PATH

                        # Transfer the zip file to the NiFi EC2 instance using SCP
                        scp -i $KEY_PATH -o StrictHostKeyChecking=no \
                            nifi-assembly/target/nifi-1.26.0-bin.zip \
                            ubuntu@$NIFI_IP:/home/ubuntu/

                        # SSH into the EC2 instance and unzip
                        ssh -i $KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NIFI_IP << EOF
                            unzip -o /home/ubuntu/nifi-1.26.0-bin.zip -d /home/ubuntu/
                            echo "NiFi unzipped successfully."
EOF
                    '''
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