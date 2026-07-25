pipeline {
    agent any

    environment {
        BACKEND_REPO  = 'https://github.com/buiminh-afk/devops-bootcamp-todolist-backend-api.git'
        FRONTEND_REPO = 'https://github.com/buiminh-afk/devops-bootcamp-todolist-frontend.git'

        BACKEND_IMAGE  = 'buiminh03/vntechies-todolist-backend'
        FRONTEND_IMAGE = 'buiminh03/vntechies-todolist-frontend'

        APP_HOST = '10.0.1.178'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                deleteDir()
            }
        }

        stage('Checkout Sources') {
            steps {
                dir('backend') {
                    git branch: 'master', url: "${BACKEND_REPO}"
                }

                dir('frontend') {
                    git branch: 'master', url: "${FRONTEND_REPO}"
                }

                script {
                    env.IMAGE_TAG = sh(
                        script: 'git -C backend rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Test Backend') {
            steps {
                dir('backend') {
                    sh '''
                        docker run --rm \
                          --user "$(id -u):$(id -g)" \
                          -e HOME=/tmp \
                          -v "$PWD:/app" \
                          -w /app \
                          node:20-alpine \
                          sh -c "npm ci && npm run build"
                    '''
                }
            }
        }

        stage('Test Frontend') {
            steps {
                dir('frontend') {
                    sh '''
                        docker run --rm \
                          --user "$(id -u):$(id -g)" \
                          -e HOME=/tmp \
                          -v "$PWD:/app" \
                          -w /app \
                          node:20-alpine \
                          sh -c "npm ci && npm run build"
                    '''
                }
            }
        }

        stage('Build Images') {
            steps {
                sh '''
                    docker build -t ${BACKEND_IMAGE}:${IMAGE_TAG} backend

                    docker build \
                      --build-arg NEXT_PUBLIC_API_URL=http://100.57.85.109:5000/api \
                      -t ${FRONTEND_IMAGE}:${IMAGE_TAG} frontend
                '''
            }
        }

        stage('Push Images') {
            when {
                branch 'main'
            }

            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_TOKEN'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_TOKEN" |
                          docker login -u "$DOCKER_USER" --password-stdin

                        docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                        docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                    '''
                }
            }
        }

        stage('Deploy Dev') {
            when {
                branch 'main'
            }

            steps {
                sshagent(credentials: ['application-ec2-ssh']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ubuntu@${APP_HOST} "
                          cd ~/application_capstone_project/application &&
                          IMAGE_TAG=${IMAGE_TAG} docker compose pull &&
                          IMAGE_TAG=${IMAGE_TAG} docker compose up -d --remove-orphans
                        "
                    '''
                }
            }
        }

        stage('Smoke Test Dev') {
            when {
                branch 'main'
            }

            steps {
                sh '''
                    curl -f http://${APP_HOST}:5000/health
                    curl -f http://${APP_HOST}:3000
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
    }
}
