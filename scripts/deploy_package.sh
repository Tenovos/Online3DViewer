#!/bin/bash

# Set AWS_PROFILE to desired account.
# ex: AWS_PROFILE=ninja ./deploy_package.sh

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

# Check if S3 Bucket exists in account
echo "Checking if tenovos-3d-object-viewer S3 Bucket exists"
S3_BUCKET=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'tenovos-3d-object-viewer')].Name" --output text)
if [[ $S3_BUCKET ]]
then
    echo "S3 Bucket already exists. Continuing..."
else
    echo "S3 Bucket does not exist. Creating required bucket..."
    aws s3api create-bucket --bucket tenovos-3d-object-viewer-$AWS_PROFILE --region us-east-1
fi

# Check if CloudFront Distribution exists for bucket
echo "Checking for existing CloudFront Distribution"
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[*].{id:Id,origin:Origins.Items[0].Id}[?contains(origin, 'tenovos-3d-object-viewer')].id" --output text)
if [[ $DISTRIBUTION_ID ]]
then
    echo "Distribution [$DISTRIBUTION_ID] already exists for bucket."
else
    echo "Distribution does not exist for bucket. Creating new distribution..."
    aws cloudfront create-distribution --origin-domain-name tenovos-3d-object-viewer-$AWS_PROFILE.s3.amazonaws.com
    aws cloudfront create-origin-access-control --origin-access-control-config Name=tenovos-3d-object-viewer-$AWS_PROFILE.s3.us-east-1.amazonaws.,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3

    DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[*].{id:Id,origin:Origins.Items[0].Id}[?contains(origin, 'tenovos-3d-object-viewer')].id" --output text)

    DISTRIBUTION_ARN=$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.ARN' --output text)
    s3PolicyJson=s3-policy.json
    echo "$( jq '.Statement[].Resource = "arn:aws:s3:::tenovos-3d-object-viewer-'$AWS_PROFILE'/*" | .Statement[].Condition.StringEquals."AWS:SourceArn" = "'$DISTRIBUTION_ARN'"' $s3PolicyJson)" > $s3PolicyJson

    aws s3api put-bucket-policy --bucket tenovos-3d-object-viewer-$AWS_PROFILE --policy file://$s3PolicyJson
fi

# Upload package to S3 Bucket
echo "Uploading 3D Viewer to tenovos-3d-object-viewer-$AWS_PROFILE"
aws s3 sync ./deploy s3://tenovos-3d-object-viewer-$AWS_PROFILE

# Create invalidation for CloudFront distribution
echo "Creating invalidation for $DISTRIBUTION_ID"
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/tenovos-3d-object-viewer-$AWS_PROFILE/*"

echo "Done in $AWS_PROFILE"
