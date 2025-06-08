# 🚀 Jenkins CI Pipeline

This pipeline handles the **Continuous Integration** process:

- Clones the Node.js project from GitHub
- Builds the Docker image
- Archives a `.tar.gz` build artifact
- Pushes the image to:
  - Docker Hub (if ENV = `DEV`)
  - JFrog Artifactory (if ENV = `PROD`)

It is triggered manually with an `ENVIRONMENT` choice parameter.

### 📦 CI Pipeline Screenshot

<p align="center">
  <img src="ci image.png" width="450" alt="CI Pipeline Screenshot"/>
</p>