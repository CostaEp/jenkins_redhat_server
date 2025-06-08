FROM registry.access.redhat.com/ubi8/ubi

ENV JENKINS_VERSION=2.440.3
ENV JENKINS_HOME=/var/lib/jenkins
ENV JENKINS_USER=jenkins
ENV JENKINS_GROUP=jenkins

# install java (jdk17) and updates - clean all (delete all cash for small image)  
RUN dnf update -y && \
    dnf install -y java-17-openjdk wget git unzip shadow-utils sudo && \
    dnf clean all

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
