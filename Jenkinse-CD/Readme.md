# 🚀 Jenkins CD Pipeline

This pipeline handles the **Continuous Deployment** process:

- Pulls the latest Docker image based on the selected environment (DEV or PROD)
- Runs the container locally on port 8082
- Replaces existing container if exists

Use this pipeline to deploy the app after the CI job finishes successfully.