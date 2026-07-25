pipeline {
  agent any

  environment {
    DOCKERHUB_USERNAME = 'buiminh03'
    BACKEND_IMAGE = 'buiminh03/vntechies-todolist-backend:dev'
    BACKEND_REPO_URL = 'https://github.com/buiminh-afk/devops-bootcamp-todolist-backend-api.git'
  }

  stages {
    stage('Checkout backend repo') {
      steps {
        dir('backend-src') {
          git branch: 'main', url: BACKEND_REPO_URL
        }
      }
    }

    stage('Build backend image') {
      steps {
        dir('backend-src') {
          sh 'docker build -t ${BACKEND_IMAGE} .'
        }
      }
    }

    stage('Push backend image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
          sh 'docker push ${BACKEND_IMAGE}'
        }
      }
    }
  }
}
