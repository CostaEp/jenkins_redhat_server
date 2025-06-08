### build image 

```docker build -t jenkins-ubi . ```


### create volume for jenkins

```
docker volume create jenkins_data
```
```
docker network create jenkins-net
```


### run docker image


```docker run -d \
  --name jenkins-ubi \
  --restart unless-stopped \
  -p 8080:8080 \
  -v jenkins_data:/var/lib/jenkins \
  --network jenkins-net \
  jenkins-ubi
  ```