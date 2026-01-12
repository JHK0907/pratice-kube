pipeline {
    agent any

    environment {
        HARBOR_URL       = '192.168.63.99'
        HARBOR_PROJECT   = 'test'
        IMAGE_NAME       = 'test/nginx'
        IMAGE_TAG        = "test/nginx:latest"
        HARBOR_CRED_ID   = 'harbor-credentials'
        K8S_CRED_ID      = 'kubeconfig-credentials'
        PRISMA_API_URL   = "https://api.jp.prismacloud.io"
        // Jenkins Job SCM URL (e.g., 'your-git-server.com/user/repo') and branch will be used by Checkov
        // Ensure the SCM URL is correctly configured in the Jenkins job
        REPO_ID          = "192.168.63.99/test/nginx"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install & Test') {
            tools {
                nodejs 'node-16' // Jenkins Global Tool Configuration에 설정된 Node.js 이름
            }
            steps {
                sh 'npm install'
                sh 'npm test'
            }
        }

        stage('Checkov Security Scan') {
            steps {
                withCredentials([
                    
withCredentials([string(credentialsId: 'BC_API_KEY', variable: 'BC_API_KEY')]) {
    script {
        docker.image('bridgecrew/checkov:latest').inside("--entrypoint=''") {
            try {
                sh """
                    checkov -d . \
                        -o cli \
                        -o junitxml \
                        --output-file-path console,results.xml \
                        --bc-api-key ${BC_API_KEY} \
                        --repo-id ${REPO_ID}
                """
                junit skipPublishingChecks: true, testResults: 'results.xml'
            } catch (err) {
                junit skipPublishingChecks: true, testResults: 'results.xml'
                throw err
            }
        }
    }
}

                ]) {
                    script {
                        docker.image('bridgecrew/checkov:latest').inside("--entrypoint=''") {
                            try {
                                sh "checkov -d . --use-enforcement-rules -o cli -o junitxml --output-file-path console,results.xml --bc-api-key ${pc_user}::${pc_password} --repo-id ${REPO_ID} --branch ${scm.branches[0].name}"
                                junit skipPublishingChecks: true, testResults: 'results.xml'
                            } catch (err) {
                                junit skipPublishingChecks: true, testResults: 'results.xml'
                                throw err
                            }
                        }
                    }
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                script {
                    def fullImageName = "${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
                    
                    withCredentials([usernamePassword(credentialsId: HARBOR_CRED_ID, usernameVariable: 'HARBOR_USER', passwordVariable: 'HARBOR_PASS')]) {
                        // Docker 이미지 빌드
                        def customImage = docker.build(fullImageName, '.')
                        
                        // Harbor에 로그인하고 이미지를 푸시합니다.
                        docker.withRegistry("http://${HARBOR_URL}", HARBOR_CRED_ID) {
                            customImage.push()
                        }
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    def fullImageName = "${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
                    
                    withKubeconfig([credentialsId: K8S_CRED_ID]) {
                        // 1. 배포 파일의 이미지 태그를 현재 빌드 버전으로 교체합니다.
                        sh "sed -i 's|image: .*|image: ${fullImageName}|g' k8s/deployment.yaml"
                        
                        // 2. kubectl을 사용하여 업데이트된 설정 파일을 클러스터에 적용합니다.
                        sh "kubectl apply -f k8s/"
                        
                        // 3. 배포 상태를 확인합니다.
                        sh "kubectl rollout status deployment/vmtest-app-deployment"
                    }
                }
            }
        }
    }

    options {
        preserveStashes()
        timestamps()
    }
}