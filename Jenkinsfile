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
        string(name: 'EKS_CLUSTER_NAME', defaultValue: 'my-eks-cluster', description: 'Name of the EKS cluster provosioned by Terraform')
        string(name: 'AWS_REGION', defaultValue: 'us-west-2', description: 'Name of the AWS region where Terraform provisions resources')
    }

    environment {
        GIT_CREDS       = 'github_credentials'
        DOCKER_CREDS    = 'dockerhub_credentials'
        SSH_KEY         = 'nifi_ssh_key'
        REPO_URL        = 'https://github.com/apache/nifi.git'
        REPO_BRANCH     = "refs/tags/rel/nifi-${params.NIFI_VERSION}"
        // NIFI_VERSION    = 'nifi-1.26.0'
        // AWS_REGION      = 'us-west-2' // hard-coded, make sure this matches whatever is in terraform scripts
        IMAGE_NAME      = "${params.DOCKERHUB_USER}/nifi-custom"
        FULL_TAG        = "${IMAGE_NAME}:${params.IMAGE_TAG}"
        PERSONAL_GIT_REPO = 'https://github.com/jeremiahdy55/NiFi-CICDPractice.git'
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


        // Option 1: manually build, create zip, then run the zip later
        stage('Build nifi-assembly into a zip') {
            steps {
                dir('nifi-assembly') {
                    sh 'mvn clean install -DskipTests'

                    sh """
                        cd target/nifi-${params.NIFI_VERSION}-bin/nifi-${params.NIFI_VERSION}
                        rm -rf docs LICENSE NOTICE README
                        cd ..
                        zip -r ../../../${params.NIFI_VERSION}-bin.zip .
                    """
                }
            }
        }


        // Option 2: create the docker image
        stage('Prepare Docker Context') {
            steps {
                script {
                    // Clone your personal repo that contains the Dockerfile
                    dir('infra') {
                        checkout([$class: 'GitSCM', 
                            branches: [[name: 'main']], 
                            userRemoteConfigs: [[
                                url: env.PERSONAL_GIT_REPO,
                                credentialsId: env.GIT_CREDS
                            ]]
                        ])
                    }

                    // Create docker build context
                    sh 'mkdir -p docker'

                    // Copy your Dockerfile from infra repo to build context
                    sh 'cp infra/Dockerfile docker/Dockerfile'

                    // Copy NiFi build output from this pipeline into docker context
                    // sh "cp -r nifi-assembly/target/nifi-${params.NIFI_VERSION}-bin docker/nifi-bin"
                    sh "cp -r nifi-assembly/target/nifi-${params.NIFI_VERSION}-bin/nifi-${params.NIFI_VERSION} docker/nifi-bin"
                }
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


        stage('Copy artifact to NiFi server via SFTP') {
            steps {
                sshagent([env.SSH_KEY]) {
                    script {
                        sh """
                            # Fetch S3_BUCKET Address
                            S3_BUCKET=\$(grep '^S3_BUCKET=' /etc/environment | cut -d '=' -f2)
                            
                            # Fetch NiFi EC2 Instance's public IP from S3
                            aws s3 cp s3://\$S3_BUCKET/nifi_ip.txt nifi_ip.txt
                            NIFI_IP=\$(cat nifi_ip.txt)

                            # Transfer the zip file to the NiFi EC2 instance using SCP (no -i needed)
                            scp -o StrictHostKeyChecking=no \
                                ./${env.NIFI_VERSION}-bin.zip \
                                ubuntu@\$NIFI_IP:/home/ubuntu/

                            # SSH into the EC2 instance and unzip
                            ssh -o StrictHostKeyChecking=no ubuntu@\$NIFI_IP << EOF
                                unzip -o /home/ubuntu/${env.NIFI_VERSION}-bin.zip -d /home/ubuntu/
                                echo "NiFi unzipped successfully."
EOF
                        """
                    }
                }
            }
        }

        stage('Configue kubeconfig and Deploy to EKS') {
            when {
                expression { currentBuild.currentResult == 'SUCCESS' }
            }
            steps {
                sh """
                    set -e
                    aws eks update-kubeconfig --region ${params.AWS_REGION} --name ${params.EKS_CLUSTER_NAME}
                """
                dir('infra') {
                    sh """
                        set -e
                        export FULL_TAG=${FULL_TAG}

                        kubectl create namespace nifi || true
                        kubectl apply -f k8s/storage.yaml -n nifi
                        kubectl apply -f k8s/statefulset.yaml -n nifi
                        kubectl rollout status statefulset/nifi -n nifi --timeout=10m
                        kubectl apply -f k8s/service.yaml -n nifi
                    """
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
