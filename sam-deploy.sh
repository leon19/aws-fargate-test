#!/usr/bin/env bash

set -e

export AWS_PAGER=""

if [ -z "$AWS_REGION" ]; then
  echo "AWS_REGION is not set. Exiting."
  exit 1
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "AWS_ACCOUNT_ID is not set. Exiting."
  exit 2
fi

DOCKER_REPO_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
DOCKER_IMAGE_NAME=$(jq < package.json -r '.name')
DOCKER_IMAGE_TAG=$(jq < package.json -r '.version')

DOCKER_IMAGE=$DOCKER_REPO_URL/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG

# Crete the in AWS ECR if it does not exist already
aws ecr describe-repositories --output table --repository-names "$DOCKER_REPO_URL/$DOCKER_IMAGE_NAME" 2>/dev/null \
  || aws ecr create-repository --output table --repository-name "$DOCKER_REPO_URL/$DOCKER_IMAGE_NAME"

# Build the Docker image
docker build . -t "$DOCKER_IMAGE"

# Push the Docker image to ECR
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$DOCKER_REPO_URL"
docker push "$DOCKER_IMAGE"

# Deploy the application. The application relies on the existence of the Docker image in ECR
# Otherwise, the deployment will never reach the created state
sam deploy --parameter-overrides "ImageName=$DOCKER_IMAGE_NAME ImageTag=$DOCKER_IMAGE_TAG"
sam list stack-outputs