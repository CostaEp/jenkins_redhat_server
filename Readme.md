# Jenkins CI/CD with Docker on RedHat UBI8

This repository demonstrates a full CI/CD pipeline using Jenkins running in a custom Docker container based on RedHat UBI 8. The pipeline builds a Docker image of a Node.js application and pushes it to Docker Hub.

---

## 🏗️ Custom Jenkins Dockerfile

The Jenkins image is based on UBI8 with Java 17, Docker CLI, Git, and Jenkins WAR installed:

```dockerfile
FROM registry.access.redhat.com/ubi8/ubi

ENV JENKINS_VERSION=2.440.3
ENV JENKINS_HOME=/var/lib/jenkins
ENV JENKINS_USER=jenkins
ENV JENKINS_GROUP=jenkins

# install java (jdk17) and updates - clean all (delete all cash for small image)  
RUN dnf update -y && \
    dnf install -y java-17-openjdk wget git unzip shadow-utils sudo && \
    dnf clean all

# Install Docker CLI manually (no RHEL subscription needed)
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-24.0.5.tgz -o docker.tgz && \
    tar xzvf docker.tgz && \
    mv docker/docker /usr/bin/ && \
    chmod +x /usr/bin/docker && \
    rm -rf docker docker.tgz
# create group and jenkiins user
RUN groupadd -g 1000 $JENKINS_GROUP && \
    useradd -u 1000 -g $JENKINS_GROUP -m -d $JENKINS_HOME -s /bin/bash $JENKINS_USER

# downloading jenkins
RUN mkdir -p /opt/jenkins && \
    wget https://get.jenkins.io/war-stable/${JENKINS_VERSION}/jenkins.war -O /opt/jenkins.war && \
    chown -R ${JENKINS_USER}:${JENKINS_GROUP} /opt/jenkins

# expose port number 808 for jenkins
EXPOSE 8080

# run jenkins as a jenkins user
USER $JENKINS_USER

ENTRYPOINT ["java", "-jar", "/opt/jenkins.war"]
```

## 🏗️ Docker commands:
### build image 

```docker build -t jenkins-ubi . ```

### create volume for jenkins

```
docker volume create jenkins_data
```

### create network for jenkins

```
docker network create jenkins-net
```

### run docker image

```
docker run -d \
  --name jenkins-ubi \
  -u root \
  --restart unless-stopped \
  -p 8080:8080 \
  -v jenkins_data:/var/lib/jenkins \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --network jenkins-net \
  jenkins-ubi
  ```

## 🚀 Jenkins Pipeline (Jenkinsfile)

```Jenkinsfile

pipeline {
    agent any

    environment {
        DOCKER_USERNAME = 'YOUR DOCKER HUB USER NAME'
        IMAGE_NAME = "${DOCKER_USERNAME}/YOUR IMAGE NAME"
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
                    git branch: 'main', url: 'https://github.com/REPO NAME.....'
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

```

## 🔐 Jenkins Credentials

1. Go to **Jenkins > Manage Jenkins > Credentials**
2. Add a new **Username/Password** credential:
   - **ID**: `dockerhub`
   - **Username**: your Docker Hub username (e.g., `YOUR DOCKER HUB USER NAME`)
   - **Password**: your Docker Hub password or personal access token

## 📦 Push Docker Image to Docker Hub
Make sure your IMAGE_NAME is in the format username/repo and you are logged in to Docker Hub.
Example image name:

```
IMAGE_NAME = ${IMAGE_NAME}:${IMAGE_TAG}
```


### ✨ Author
## Created by Costa Epshtein

