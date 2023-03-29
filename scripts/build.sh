#!/bin/bash

# Set AWS_PROFILE to desired account.
# ex: AWS_PROFILE=ninja ./deploy_package.sh

while (($# > 1)); do
  case $1 in
  --profile) PROFILE="$2" ;;
  --ssm) SSM="$2" ;;
  *) break ;;
  esac
  shift 2
done

#Set default local deployment tags
if [ -z "$TAGS_JENKINS_JOB_NAME" ]
then
  TAGS_IAM_USER="tnvs:platform:delivery:iam-user="$(aws sts get-caller-identity --profile $PROFILE --query '[Arn]' --output text | sed 's|.*/||')
  TAGS_GIT_COMMIT_SHA="tnvs:platform:delivery:git-commit-sha="$(git rev-parse HEAD)
  TAGS_BRANCH="tnvs:platform:delivery:branch="$(git rev-parse --abbrev-ref HEAD)
fi

REGION=us-east-1

if [ "x"$REQUESTED_REGION == 'xus-west-2' ]
then
  REGION=us-west-2
fi

if [[ -z "$STACK_NAME" ]] || [[ -z "$PARAMETERS" ]] || [[ -z "$TEMPLATE" ]] || [[ -z "$PROFILE" ]]; then
  display_usage
  exit 1
fi

if [[ "$1" = '--help' ]]; then
  display_usage
  exit 1
fi
npm run build_dev

# Stage Package for Deployment
rm -rf deploy/*
mkdir -p deploy/assets/
cp -rf assets/icons deploy/assets/
cp -rf build deploy/
cp -rf libs deploy/
mkdir -p deploy/website/assets/envmaps
cp -rf website/assets/envmaps/default deploy/website/assets/envmaps/
cp website/assets/envmaps/default.jpg deploy/website/assets/envmaps/
cp -rf website/assets/images deploy/website/assets/
cp -rf website/css deploy/website/
cp website/embed.html deploy/website/
cp website/index_min.html deploy/website/

# Include Sample Models
mkdir deploy/website/assets/models
# cp website/assets/models/car.glb deploy/website/assets/models/
