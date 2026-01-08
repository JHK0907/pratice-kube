pipeline {
    agent any

    environment {
        HARBOR_URL      = '192.168.63.99'
        HARBOR_PROJECT  = 'library'
        IMAGE_NAME      = 'vmtest-app'
        // Jenkins의 빌드 번호를 이미지 태그로 사용
        IMAGE_TAG       = "build-${BUILD_NUMBER}"
        // Harbor Credential ID (Jenkins에서 생성)
        HARBOR_CRED_ID  = 'harbor-credentials'
        // Kubernetes Kubeconfig Credential ID (Jenkins에서 생성)
        K8S_CRED_ID     = 'kubeconfig-credentials'
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

        stage('Build & Push Docker Image') {
            steps {
                script {
                    def fullImageName = "${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
                    
                    // Harbor 인증서가 사설인 경우 Jenkins Docker 데몬에 insecure-registry로 등록해야 합니다.
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
                    
                    // withKubeconfig를 사용하여 K8s 클러스터 접근 정보를 관리합니다.
                    withKubeconfig([credentialsId: K8S_CRED_ID]) {
                        // 1. 배포 파일의 이미지 태그를 현재 빌드 버전으로 교체합니다.
                        // (주의: macOS/BSD의 sed와 호환되도록 -i '' 옵션을 사용)
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
}
