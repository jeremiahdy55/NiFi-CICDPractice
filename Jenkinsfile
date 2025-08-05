pipeline {
    agent any

    // **tools** must be configured in Jenkins-Tools
    tools {
        maven 'maven3.9.3' 
    }

    

    parameters {
        string(name: 'NIFI_VERSION', defaultValue: '1.26.0', description: 'NiFi version to build')
        string(name: 'DOCKERHUB_USER', defaultValue: 'jeremiahjava55', description: 'Docker Hub username')
        string(name: 'IMAGE_TAG', defaultValue: '1.26.0', description: 'Docker image tag')
    }

    environment {
        GIT_CREDS       = 'github_credentials'
        DOCKER_CREDS    = 'dockerhub_credentials'
        SSH_KEY         = 'nifi_ssh_key'
        REPO_URL        = 'https://github.com/apache/nifi.git'
        REPO_BRANCH     = "refs/tags/rel/nifi-${params.NIFI_VERSION}"
        // NIFI_VERSION    = 'nifi-1.26.0'
        AWS_REGION      = 'us-west-2' // hard-coded, make sure this matches whatever is in terraform scripts
        IMAGE_NAME      = "${params.DOCKERHUB_USER}/nifi-custom"
        FULL_TAG        = "${IMAGE_NAME}:${params.IMAGE_TAG}"
    }

    

    stages {

        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        
        stage('Checkout') {
            steps {
                checkout([$class: 'GitSCM', 
                    branches: [[name: env.REPO_BRANCH]], 
                    userRemoteConfigs: [[
                        url: "${env.REPO_URL}",
                        credentialsId: "${env.GIT_CREDS}"
                    ]]
                ])
            }
        }


        stage('Build nifi-assembly') {
            steps {
                dir('nifi-assembly') {
                    sh 'mvn clean install -DskipTests'

                    // sh """
                    //     cd target/${env.NIFI_VERSION}-bin
                    //     zip -r ../../../${env.NIFI_VERSION}-bin.zip .
                    // """
                }
            }
        }

        stage('Prepare Docker Context') {
            steps {
                sh """
                    mkdir -p docker
                    cat > docker/Dockerfile <<'EOF'
FROM eclipse-temurin:17-jre-jammy

RUN useradd --no-create-home --shell /bin/false nifi

RUN apt-get update && \\
    apt-get install -y --no-install-recommends ca-certificates curl && \\
    rm -rf /var/lib/apt/lists/*

# Copy pre-built NiFi directory into image
COPY nifi-bin/ /opt/nifi/

RUN chown -R nifi:nifi /opt/nifi

ENV NIFI_HOME=/opt/nifi
ENV PATH=\$NIFI_HOME/bin:\$PATH
ENV NIFI_WEB_HTTP_PORT=8080

EXPOSE 8080
USER nifi
ENTRYPOINT ["/opt/nifi/bin/nifi.sh", "run"]
EOF

                    # Copy the built NiFi bin directory to docker context
                    cp -r nifi-assembly/target/nifi-${params.NIFI_VERSION}-bin docker/nifi-bin
                """
            }
        }

         stage('Build & Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: "${env.DOCKER_CREDS}", 
                        usernameVariable: 'DH_USER', 
                        passwordVariable: 'DH_PASS'
                    )
                ]) {
                    dir('docker') {
                        sh '''
                            docker version >/dev/null 2>&1 || { echo "Docker daemon unreachable"; exit 1; }

                            # Pre-pull base image
                            docker pull eclipse-temurin:17-jre-jammy

                            echo "$DH_PASS" | docker login --username "$DH_USER" --password-stdin
                            docker build -t ${FULL_TAG} .
                            docker push ${FULL_TAG}
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


//         stage('Copy artifact to NiFi server via SFTP') {
//             steps {
//                 sshagent([env.SSH_KEY]) {
//                     script {
//                         sh """
//                             # Fetch S3_BUCKET Address
//                             S3_BUCKET=\$(grep '^S3_BUCKET=' /etc/environment | cut -d '=' -f2)
                            
//                             # Fetch NiFi EC2 Instance's public IP from S3
//                             aws s3 cp s3://\$S3_BUCKET/nifi_ip.txt nifi_ip.txt
//                             NIFI_IP=\$(cat nifi_ip.txt)

//                             # Transfer the zip file to the NiFi EC2 instance using SCP (no -i needed)
//                             scp -o StrictHostKeyChecking=no \
//                                 ./${env.NIFI_VERSION}-bin.zip \
//                                 ubuntu@\$NIFI_IP:/home/ubuntu/

//                             # SSH into the EC2 instance and unzip
//                             ssh -o StrictHostKeyChecking=no ubuntu@\$NIFI_IP << EOF
//                                 unzip -o /home/ubuntu/${env.NIFI_VERSION}-bin.zip -d /home/ubuntu/
//                                 echo "NiFi unzipped successfully."
// EOF
//                         """
//                     }
//                 }
//             }
//         }