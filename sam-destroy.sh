#!/usr/bin/env bash

set -e

export AWS_PAGER=""

if [ -z "$AWS_REGION" ]; then
  echo "AWS_REGION is not set. Exiting."
  exit 1
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "AWS_ACCOUNT_ID is not set. Exiting."
  exit 1
fi

DOCKER_REPO_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
DOCKER_IMAGE_NAME=$(jq < package.json -r '.name')

# Delete the SAM application
sam delete --no-prompts

# Delete the ECR repository and its contents
aws ecr delete-repository --output table --repository-name "$DOCKER_REPO_URL/$DOCKER_IMAGE_NAME" --force
