pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'github_credentials'
        REPO_URL        = 'https://github.com/apache/nifi.git'
        AWS_REGION      = 'us-west-2' // hard-coded, make sure this matches whatever is in terraform scripts
    }

    // **tools** must be setup in Jenkins-Tools config
    tools {
        maven 'maven3.9.3' 
        // jdk 'jdk17'
    }

    stages {
        stage('Load S3 bucket name from /etc/environment') {
            steps {
                script {
                    def s3Bucket = sh(script: "grep '^S3_BUCKET=' /etc/environment | cut -d '=' -f2", returnStdout: true).trim()
                    env.S3_BUCKET = s3Bucket
                    echo "Loaded S3_BUCKET from /etc/environment: ${env.S3_BUCKET}"
                }
            }
        }
        
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
                    // cd to target
                    dir('target') {
                        sh 'zip -r nifi-1.26.0-bin.zip nifi-1.26.0-bin'
                    }
                }
            }
        }

// stage('Copy artifact to NiFi server via SFTP') {
//   steps {
//     sshagent(['nifi_ssh_key']) {
//       sh '''
//         sftp -o StrictHostKeyChecking=no ubuntu@<nifi-ec2-public-ip> <<EOF
//         put nifi-assembly/target/nifi-1.26.0-bin.zip /home/ubuntu/nifi-1.26.0-bin.zip
//         bye
// EOF
//       '''
//     }
//   }
// }
    }

    post {
        success{
            echo 'Build success!'
        }
        failure{
            echo 'Build failure :('
        }
        // success {
        //     echo 'All microservices built and pushed successfully! Proceeding to deploy to EKS.'

        //     script {
        //         // Configure kubectl
        //         sh """
        //             set -e
        //             aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
        //             kubectl get nodes
        //         """

        //         // Loop through services and deploy
        //         def services = ['order-ms', 'delivery-ms', 'payment-ms', 'stock-ms']
        //         services.each { svc ->
        //             dir("${svc}/k8s") {
        //                 sh "kubectl apply -f deployment.yaml"
        //                 sh "kubectl apply -f service.yaml"
        //                 sh "kubectl rollout status deployment/${svc}-deployment || true"
        //             }
        //         }
        //     }
        // }

        // failure {
        //     echo 'Pipeline failed before deployment.'
        // }
    }
}