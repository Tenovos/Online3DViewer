#!/bin/bash

# Provide comma separated list of accounts to deploy to (or one account).
# ex: ./deploy_package.sh ninja,ninja2

# Read accounts into array
IFS=',' read -r -a accountsArray <<< "$1"

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

# Upload package to S3 for each account
for ACCOUNT in "${accountsArray[@]}"
do
    echo "Uploading 3D Viewer to $ACCOUNT"
    aws s3 sync ./deploy s3://tenovos-web-ui-baseline-$ACCOUNT/viewer/3d-object --profile $ACCOUNT

    echo "Retrieving CloudFront Distribution ID for $ACCOUNT"
    DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[*].{id:Id,origin:Origins.Items[0].Id}[?contains(origin, 'S3-tenovos-web-ui-baseline')].id" --output text --profile $ACCOUNT)
    echo "Distribution ID is: $DISTRIBUTION_ID"

    echo "Creating invalidation for $DISTRIBUTION_ID"
    aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/tenovos-web-ui-baseline-$ACCOUNT/viewer/3d-object/*" --profile $ACCOUNT

    echo "Done in $ACCOUNT"
done
