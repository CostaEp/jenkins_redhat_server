# Jenkins CI/CD with Docker on RedHat UBI8  
![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-blue)  
![Docker](https://img.shields.io/badge/Docker-Image-green)  
![JFrog](https://img.shields.io/badge/JFrog-Artifactory-orange)

This repository demonstrates a full CI/CD pipeline using Jenkins running in a custom Docker container based on RedHat UBI 8. The pipeline builds a Docker image of a Node.js application and pushes it to Docker Hub.

---

## 📁 Project Structure

```shell

jenkins_redhat_server/
│
├── Dockerfile                # Jenkins custom image (UBI8)
├── Jenkins-CI/
│   └── Jenkinsfile           # CI pipeline
├── Jenkinse-CD/
│   └── Jenkinsfile           # CD pipeline
└── README.md

```

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

## 🧱 Docker Setup
### build image 

```docker build -t jenkins-ubi . ```

### 🗃️ Create Jenkins Volume

```
docker volume create jenkins_data
```

### 🌐 Create Docker Network

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

## 🚀 Jenkins Pipeline ['Checkout','Build Docker Image','Push'] (CI)

```groovy

pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['DEV', 'PROD'],
            description: 'Choose the environment to deploy to'
        )
    }

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
                    sh 'tar --exclude=build -czf build/artifact.tar.gz .'
                    // archiveArtifacts artifacts: 'build/*.tar.gz', followSymlinks: false
                }
            }
        }

        stage('Push to JFrog') {
            when {
                expression { params.ENVIRONMENT == 'PROD' }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'jfrog-docker', usernameVariable: 'JFROG_USER', passwordVariable: 'JFROG_PASS')]) {
                    // sh '''
                    //     echo "$JFROG_PASS" | docker login trialam94b7.jfrog.io --username "$JFROG_USER" --password-stdin

                    //     docker tag ${IMAGE_NAME}:${IMAGE_TAG} trialam94b7.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
                    //     docker push trialam94b7.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
                    // '''
                    sh '''
                        echo "$JFROG_PASS" | docker login trialam94b7.jfrog.io --username "$JFROG_USER" --password-stdin

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} trialam94b7.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:latest trialam94b7.jfrog.io/docker-local/${IMAGE_NAME}:latest

                        docker push trialam94b7.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push trialam94b7.jfrog.io/docker-local/${IMAGE_NAME}:latest
                    '''
                }
            }
        }

        stage('Push to DockerHub') {
            when {
                expression { params.ENVIRONMENT == 'DEV' }
            }
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
    post {
        success {
            echo "Build ${BUILD_NUMBER} completed successfully for ${params.ENVIRONMENT}"
        }
        failure {
            echo "Build ${BUILD_NUMBER} failed for ${params.ENVIRONMENT}"
        }
        always {
            archiveArtifacts artifacts: 'source/build/*.tar.gz', followSymlinks: false
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

## 📦 Image Naming & Push to Docker Hub
•	Make sure your IMAGE_NAME is in the format:
```
username/repository-name
```
•	The image will be tagged as:
```
IMAGE_NAME = ${IMAGE_NAME}:${IMAGE_TAG}
```

## 📦 Archive Build Artifact in Jenkins

The pipeline also creates and stores an artifact (tar.gz) of the working directory:

### 🔁 In Jenkinsfile:

```groovy
sh 'mkdir -p build'
sh 'tar --exclude=build -czf build/artifact.tar.gz .'
archiveArtifacts artifacts: 'build/*.tar.gz', followSymlinks: false
```
•   This step is done inside the source/ folder

•   The archive will appear in Jenkins under "Artifacts" of the job run

You can use this artifact in later stages (deployment, backup, etc.) or download it manually.


## ☁️ Push Docker Image to JFrog Artifactory

In addition to Docker Hub, this pipeline supports pushing the image to a private JFrog Artifactory Docker registry.

### JFrog Push Section.

### 🔐 JFrog Credentials

1. Go to **Jenkins > Manage Jenkins > Credentials**

2. Add a new **Username/Password** credential:

    - **ID**: jfrog-docker

    - **Username**: your JFrog username or email (e.g., `YOUR JFROG USER NAME`)

    - **Password**: API token from your JFrog account

### 🧱 Add Push to JFrog Stage to Jenkinsfile

```groovy

stage('Push to JFrog') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'jfrog-docker', usernameVariable: 'JFROG_USER', passwordVariable: 'JFROG_PASS')]) {
            sh '''
                echo "$JFROG_PASS" | docker login XXXXXXX.jfrog.io --username "$JFROG_USER" --password-stdin

                docker tag ${IMAGE_NAME}:${IMAGE_TAG} XXXXXXX.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
                docker push XXXXXXX.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
            '''
        }
    }
}

```

*🔁 Replace XXXXXXX.jfrog.io with your actual JFrog domain if needed.*

### 🔎 Verify Image in JFrog

•   To confirm that the image has been successfully pushed:

1. Login to your JFrog Artifactory web UI

2. Navigate to Artifactory > Artifacts > docker-local

    •   You should see your image folder (e.g., costadevop/my-portfolio) with the appropriate tags

3. You can also pull the image manually:

```groovy
docker pull XXXXXXX.jfrog.io/docker-local/${IMAGE_NAME}:${IMAGE_TAG}
```

---

## 🧩 Optional: Need More Sections?

If you'd like to expand your Jenkins CI/CD setup, I can help you create detailed sections for the following topics:

### 🔌 Recommended Jenkins Plugins

A list of must-have plugins for Docker and CI/CD workflows, including:
- **Docker Pipeline**
- **Pipeline: GitHub**
- **GitHub Branch Source**
- **Blue Ocean**
- **Credentials Binding**
- **Environment Injector**
- **Pipeline: Stage View**

These plugins enhance usability, visualization, Docker integration, and secure credentials management.

---

### 🧰 Troubleshooting Guide

Solve common issues with Jenkins running inside Docker:

#### 🔧 Docker socket permission denied:
Make sure the container runs with:
```bash
-v /var/run/docker.sock:/var/run/docker.sock
```
And that the Jenkins user inside the container has access to Docker (use root or add the user to the docker group).

## 🛠️ Troubleshooting

### ❌ Cannot push to Docker Hub

- Check that your credentials (`dockerhub` ID) are configured correctly in **Jenkins > Manage Jenkins > Credentials**
- Ensure the image name format is `username/repo`
- If you’re using Docker Hub tokens, double-check the token permissions

---

### 🧱 Git Checkout Fails

- Verify the Git URL is correct and public, or add credentials if the repo is private
- Check that `git` is installed in the Jenkins container (you can test with `git --version` in a pipeline step)

---

## 💾 Jenkins Backup & Restore with Volume

### Backup Jenkins Home

Jenkins stores all configuration and job data in `/var/lib/jenkins`.  
If you’re using a Docker volume (e.g., `jenkins_data`), you can back it up with:

```bash

docker run --rm \
  -v jenkins_data:/jenkins_data \
  -v $(pwd):/backup \
  busybox \
  tar czvf /backup/jenkins_backup.tar.gz -C /jenkins_data .

```

## 🚀 Continuous Deployment Pipeline (CD)

After successfully pushing the image to Docker Hub or JFrog (via CI), this pipeline handles the automatic deployment of the latest Docker image depending on the selected environment (DEV or PROD).

### 💡 Trigger

This pipeline is triggered manually (or from another pipeline) and deploys the latest image based on the chosen environment.

### 📁 Jenkinsfile (CD)

```groovy

pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['DEV', 'PROD'],
            description: 'Choose environment to deploy from'
        )
    }

    environment {
        DOCKER_USERNAME = 'costadevop'
        IMAGE_NAME = "${DOCKER_USERNAME}/my-portfolio"
        TAG  = "latest"
        JFROG_REGISTRY = "trialam94b7.jfrog.io/docker-local"
    }

    stages {
        stage('Pull Docker Image') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'DEV') {
                        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                            sh '''
                                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                                docker pull ${IMAGE_NAME}:${TAG}
                            '''
                        }
                    } else if (params.ENVIRONMENT == 'PROD') {
                        withCredentials([usernamePassword(credentialsId: 'jfrog-docker', usernameVariable: 'JFROG_USER', passwordVariable: 'JFROG_PASS')]) {
                            sh '''
                                echo "$JFROG_PASS" | docker login $JFROG_REGISTRY --username "$JFROG_USER" --password-stdin
                                docker pull $JFROG_REGISTRY/${IMAGE_NAME}:${TAG}
                            '''
                        }
                    }
                }
            }
        }

        stage('Run Docker Container') {
            steps {
                script {
                    def finalImage = params.ENVIRONMENT == 'PROD' 
                        ? "${env.JFROG_REGISTRY}/${IMAGE_NAME}:${TAG}" 
                        : "${IMAGE_NAME}:${TAG}"

                    sh '''
                        docker rm -f my-portfolio || true
                        docker run -d \
                            --name my-portfolio \
                            -p 8082:3000 \
                            ''' + finalImage + '''
                    '''
                }
            }
        }

        stage('Access Info') {
            steps {
                echo "Your app is running at: http://localhost:8082"
            }
        }
    }
}

```

## 📌 Notes
	•	This pipeline supports multi-registry deployments (DockerHub for DEV, JFrog for PROD).
	•	Always pulls the latest tag from the selected registry.
	•	Automatically replaces existing container on port 8082.

## 🚀 Trigger Automatically from CI?

You can also configure your CI pipeline to trigger this CD pipeline after a successful build using:

```groovy
build job: 'my-cd-pipeline', parameters: [
    string(name: 'ENVIRONMENT', value: 'PROD')
]
```

## ✨ Author
Created with 💙 by Costa Epshtein

## 📝 License

This project is licensed under the [MIT License](LICENSE). 
You are free to use, modify, and distribute this code as long as the original license is included.

## 🤝 Contributing

Contributions are welcome and greatly appreciated!

If you have suggestions for improvements, feel free to fork the repository and submit a pull request.  
For major changes, please open an issue first to discuss what you would like to change.

Please make sure your contributions follow the existing code style and pass any CI checks before submitting.

