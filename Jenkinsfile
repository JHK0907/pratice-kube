
pipeline {
  agent any

  environment {
    // ───── Registry / Image Info ─────
    HARBOR_SCHEME    = 'http'                // 필요시 'https'로 변경
    HARBOR_URL       = '192.168.63.99'
    HARBOR_PROJECT   = 'test'
    IMAGE_NAME       = 'vmtest-app'
    IMAGE_TAG        = "v${env.BUILD_NUMBER}"

    // ───── Credentials ─────
    HARBOR_CRED_ID   = 'harbor-credentials'
    K8S_CRED_ID      = 'kubeconfig-credentials'
    BC_API_CRED_ID   = 'BC_API_KEY'
    PRISMA_API_URL   = "https://api.jp.prismacloud.io"

    // ───── Repo / Scan ─────
    REPO_ID          = "192.168.63.99/test/vmtest-app"

    // ───── Soft-fail toggles ─────
    SOFT_FAIL_SECURITY = 'true'
    SOFT_FAIL_TESTS    = 'true'
  }

  options {
    timestamps()
    // ansiColor('xterm')  <-- 제거 (옵션 미지원)
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 45, unit: 'MINUTES')
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.COMMIT_SHORT = sh(script: "git rev-parse --short HEAD || echo 'unknown'", returnStdout: true).trim()
        }
      }
    }

    stage('Install & Test') {
      tools {
        nodejs 'node-16'
      }
      steps {
        // 필요 시 컬러 로그: 이 스테이지 전체를 wrap(AnsiColor)로 감싸기
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
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
              catchError(stageResult: 'UNSTABLE', buildResult: 'UNSTABLE') {
                sh '''
                  set -euxo pipefail
                  npm test
