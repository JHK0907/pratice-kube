
pipeline {
  agent any

  environment {
    // ───── Registry / Image Info ─────
    HARBOR_SCHEME    = 'https'                // 필요시 'https'로 변경
    HARBOR_URL       = '192.168.63.99'       // host 또는 host:port
    HARBOR_PROJECT   = 'test'
    IMAGE_NAME       = 'vmtest-app'
    // 태그는 빌드 번호 기반으로 동적으로 생성 (latest는 충돌/캐시 유발 가능)
    IMAGE_TAG        = "v${env.BUILD_NUMBER}"

    // ───── Credentials ─────
    HARBOR_CRED_ID   = 'harbor-credentials'
    K8S_CRED_ID      = 'kubeconfig-credentials'
    BC_API_CRED_ID   = 'BC_API_KEY'          // 기존 스캔 키
    PRISMA_API_URL   = "https://api.jp.prismacloud.io"

    // ───── Repo / Scan ─────
    REPO_ID          = "192.168.63.99/test/vmtest-app"

    // ───── Misc ─────
    // 실패를 소프트-페일 처리하고 계속 진행할지 제어 (필요시 Jenkins 파라미터로 승격 가능)
    SOFT_FAIL_SECURITY = 'true'
    SOFT_FAIL_TESTS    = 'true'
  }

  options {
    timestamps()
    ansiColor('xterm')
    // 동시 빌드 방지 (배포 충돌 방지)
    disableConcurrentBuilds()
    // 오래된 빌드 정리 (원하면 조정)
    buildDiscarder(logRotator(numToKeepStr: '20'))
    // 각 stage 최대 15분 제한 (필요에 맞게 조정)
    timeout(time: 45, unit: 'MINUTES')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          // Git 커밋 short id를 태그에 보조로 사용할 수 있음 (선택)
          env.COMMIT_SHORT = sh(script: "git rev-parse --short HEAD || echo 'unknown'", returnStdout: true).trim()
        }
      }
    }

    stage('Install & Test') {
      tools {
        nodejs 'node-16' // Jenkins Global Tool Configuration에 등록된 이름
      }
      steps {
        // npm ci가 있으면 reproducible (package-lock.json 기반)
        sh '''
          set -euxo pipefail
          if [ -f package-lock.json ]; then
            npm ci
          else
            npm install
          fi
        '''

        script {
          if (env.SOFT_FAIL_TESTS == 'true') {
            // 테스트 실패를 UNSTABLE로 표시하고 파이프라인은 계속
            catchError(stageResult: 'UNSTABLE', buildResult: 'UNSTABLE') {
              sh '''
                set -euxo pipefail
                npm test
              '''
            }
          } else {
            // 하드-페일
            sh '''
              set -euxo pipefail
              npm test
            '''
          }
        }
      }
      post {
        always {
          // Node 테스트를 JUnit으로 수집하려면 junit 리포터 설정 필요 (예: jest-junit, mocha-junit-reporter)
          // 예시 경로: **/junit-report.xml
          // 테스트 리포트가 아직 없다면 다음 라인은 주석 유지 또는 경로 맞춰 활성화
          // junit allowEmptyResults: true, testResults: '**/junit-report*.xml'
        }
      }
    }

    stage('Checkov Security Scan') {
      steps {
        withCredentials([string(credentialsId: env.BC_API_CRED_ID, variable: 'BC_API_KEY')]) {
          script {
            def runScan = {
              docker.image('bridgecrew/checkov:latest').inside("--entrypoint='' --user root") {
                sh """
                  set -euxo pipefail
                  checkov -d . \\
                    -o cli \\
                    -o junitxml \\
                    --output-file-path console,results.xml \\
                    --bc-api-key '${BC_API_KEY}' \\
                    --repo-id '${REPO_ID}'
                """
              }
            }

            if (env.SOFT_FAIL_SECURITY == 'true') {
              catchError(stageResult: 'UNSTABLE', buildResult: 'UNSTABLE') {
                runScan()
              }
            } else {
              runScan()
            }
          }
        }
      }
      post {
        always {
          // 스캔 결과를 JUnit으로 수집 (실패해도 결과는 남김)
          junit allowEmptyResults: true, skipPublishingChecks: true, testResults: 'results.xml'
        }
      }
    }

    stage('Build & Push Docker Image') {
      steps {
        script {
          def fullImageName = "${HARBOR_URL}/${HARBOR_PROJECT}/${IMAGE_NAME}:${IMAGE_TAG}"
          // 빌드/푸시는 종종 네트워크/레지스트리 문제로 일시 실패 → 재시도
          retry(2) {
            withCredentials([usernamePassword(credentialsId: HARBOR_CRED_ID, usernameVariable: 'HARBOR_USER', passwordVariable: 'HARBOR_PASS')]) {
              sh """
                set -euxo pipefail
                # 레지스트리 로그인 (플러그인 대신 CLI로 명시적 제어)
                echo "\${HARBOR_PASS}" | docker login ${HARBOR_SCHEME}://${HARBOR_URL} -u "\${HARBOR_USER}" --password-stdin

                # 빌드 (Dockerfile이 루트에 있다고 가정)
                docker build -t ${fullImageName} .

                # 푸시
                docker push ${fullImageName}

                # 로그아웃 (실패해도 무시)
                docker logout ${HARBOR_SCHEME}://${HARBOR_URL} || true
              """
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
            sh """
              set -euxo pipefail
              # 배포 파일 이미지 교체 (단순 치환; 여러 컨테이너/이미지 라인이 있다면 yq 사용 권장)
              sed -i "s|image: .*|image: ${fullImageName}|g" k8s/deployment.yaml

              # 적용
              kubectl apply -f k8s/

              # 롤아웃 대기 (배포 이름 확인 필요)
              kubectl rollout status deployment/vmtest-app-deployment --timeout=180s
            """
          }
        }
      }
    }
  }

  post {
    always {
      echo "Build completed with status: ${currentBuild.currentResult}"
    }
    failure {
      echo "Build failed. Please check the failing stage logs above."
    }
    unstable {
      echo "Build marked UNSTABLE (tests/security scan issues)."
    }
  }
}
