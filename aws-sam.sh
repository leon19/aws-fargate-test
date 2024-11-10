#!/usr/bin/env bash

set -e

export AWS_PAGER=""

STACK_PREFIX="${STACK_PREFIX:-$USER}"

DEFAULT_STACK_NAME="$STACK_PREFIX-$(jq < package.json -r '.name')"
STACK_NAME="${STACK_NAME:-$DEFAULT_STACK_NAME}"

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

sam.deploy() {
  if ! aws ecr describe-repositories --repository-names "$DOCKER_IMAGE_NAME" 2>/dev/null; then
    echo "Creating ECR repository: $DOCKER_REPO_URL/$DOCKER_IMAGE_NAME"
    aws ecr create-repository --repository-name "$DOCKER_IMAGE_NAME"
  else
    echo "ECR repository already exists: $DOCKER_REPO_URL/$DOCKER_IMAGE_NAME"
  fi

  echo "Building Docker image: $DOCKER_IMAGE"
  docker build --quiet . -t "$DOCKER_IMAGE"

  echo "Logging in to ECR"
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$DOCKER_REPO_URL"

  echo "Pushing Docker image to ECR: $DOCKER_IMAGE"
  docker push "$DOCKER_IMAGE"

  # The application relies on the existence of the Docker image in ECR
  # Otherwise, the deployment will never reach the created state
  # We pushed the image to ECR to ensure it exists before deploying the application
  echo "Deploying the application"
  echo "  - ImageName: $DOCKER_IMAGE_NAME"
  echo "  - ImageTag: $DOCKER_IMAGE_TAG"
  echo
  sam deploy \
    --stack-name "$STACK_NAME" \
    --parameter-overrides "ImageName=$DOCKER_IMAGE_NAME ImageTag=$DOCKER_IMAGE_TAG"

  sam list stack-outputs --stack-name "$STACK_NAME"
}

sam.destroy.help() {
  echo "Usage: $0 destroy [options]"
  echo
  echo "Options:"
  echo "  -e, --no-ecr  Delete the ECR repository and its contents"
}

sam.destroy.opts() {
  no_ecr=0

  while [ $# -gt 0 ] ; do
    case $1 in
      -e | --no-ecr)
        no_ecr=1
        ;;
      *)
        echo "Invalid option: $1"
        echo
        sam.destroy.help
        exit 1
        ;;
    esac
    shift
  done
}


sam.destroy() {
  sam.destroy.opts "$@"

  # Delete the SAM application
  echo "Deleting the application: $STACK_NAME"
#  sam delete --stack-name "$STACK_NAME" --no-prompts

  # Delete the ECR repository and its contents
  if [ "$no_ecr" -eq 0 ]; then
    echo "Deleting the ECR repository: $DOCKER_REPO_URL/$DOCKER_IMAGE_NAME"
#    aws ecr delete-repository --repository-name "$DOCKER_IMAGE_NAME" --force
  fi
}


ecs.redeploy() {
  # Update the ECS service with the new task definition
  cluster=$(sam list stack-outputs --stack-name "$STACK_NAME" --output json |  jq -r '.[] | select(.OutputKey == "ClusterName") | .OutputValue')
  service=$(sam list stack-outputs --stack-name "$STACK_NAME" --output json |  jq -r '.[] | select(.OutputKey == "ServiceName") | .OutputValue')
  aws ecs update-service \
    --cluster "$cluster" \
    --service "$service" \
    --force-new-deployment

  aws ecs wait services-stable --cluster "$cluster" --services "$service"
}


help() {
  echo "Usage: $0 {deploy|destroy|redeploy}"
  echo
  echo "  deploy   - Deploy the application"
  echo "  destroy  - Destroy the application"
  echo "  redeploy - Recreate the existing ECS task"
}

main() {
  case "$1" in
    deploy)
      sam.deploy "${@:2}"
      ;;
    destroy)
      sam.destroy "${@:2}"
      ;;
    redeploy)
      ecs.redeploy "${@:2}"
      ;;
    help)
      help
      ;;
    *)
      help
      exit 1
      ;;
  esac
}

main "$@"