pipeline {
    agent any

    environment {
        DOCKER_USERNAME = 'costadevop'
        IMAGE_NAME = "${DOCKER_USERNAME}/my-portfolio"
        IMAGE_TAG  = "${BUILD_NUMBER}"
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout') {
            steps {
                dir('source') {
                    git branch: 'main', url: 'https://github.com/CostaEp/my-portfolio'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('source') {
                    sh 'docker version'
                    sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                    sh "docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest"
                    sh 'docker images -a'
                    sh 'mkdir -p build'
                    sh 'tar -czf build/artifact.tar.gz .'
                   rchiveArtifacts artifacts: 'build/*.tar.gz', followSymlinks: false
                }
            }
        }

        stage('Push to JFrog') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'jfrog-docker', usernameVariable: 'JFROG_USER', passwordVariable: 'JFROG_PASS')]) {
                    sh '''
                        echo "$JFROG_PASS" | docker login trialam94b7.jfrog.io --username "$JFROG_USER" --password-stdin

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} trialam94b7.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push trialam94b7.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
                    '''
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${IMAGE_NAME}:latest
                    '''
                }
            }
        }
    }
}