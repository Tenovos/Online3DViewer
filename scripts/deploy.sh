#!/bin/bash

display_usage() {
  echo "usage: $0 --profile profile --build <yes | no> --name <bucket_prefix_name>"
  echo "example: $0 --profile dev-integration --build yes"
  echo "Name: tenovos-viewer"
  echo "Bucket: <name>-<profile> (e.g., tenovos-viewer-dev-integration)"
  echo "Path: /viewer/3d-object"
}

while (($# > 1))
do
  case $1 in
  --profile) PROFILE="$2" ;;
  --build) BUILD="$2" ;;
  --name) NAME="$2" ;;
  *) break ;;
  esac
  shift 2
done

if [[ -z "$PROFILE" ]]
then
  display_usage
  exit 1
fi

# Build Package
if [[ "$BUILD" = 'yes' ]]
then
  ./scripts/build.sh
fi

# Set Default Name
if [[ -z "$NAME" ]]
then
  NAME="tenovos-viewer"
fi

# Set Bucket
BUCKET="$NAME-$PROFILE"

# Set Path
S3_PATH="viewer/3d-object/"

# Check if S3 Bucket exists in account
echo "Checking if $BUCKET S3 Bucket exists"
S3_BUCKET=$(aws s3api list-buckets --profile $PROFILE --query "Buckets[?contains(Name, '$BUCKET')].Name" --output text)

if [[ $S3_BUCKET ]]
then
    echo "S3 Bucket $BUCKET in $PROFILE already exists. Continuing..."
else
    echo "S3 Bucket $BUCKET in $PROFILE does not exist. Creating required bucket..."
    aws s3api create-bucket --profile $PROFILE --bucket $BUCKET --region us-east-1
fi

# Check if CloudFront Distribution exists for bucket
echo "Checking for existing CloudFront Distribution"
DISTRIBUTION_ID=$(aws cloudfront list-distributions --profile $PROFILE --query "DistributionList.Items[*].{id:Id,origin:Origins.Items[0].Id}[?contains(origin, '$BUCKET')].id" --output text)
if [[ $DISTRIBUTION_ID ]]
then
  echo "Distribution [$DISTRIBUTION_ID] already exists for bucket."
else
  echo "Distribution does not exist for bucket. Creating new distribution..."
  aws cloudfront create-distribution --profile $PROFILE --origin-domain-name $BUCKET.s3.amazonaws.com --no-paginate --output text
  aws cloudfront create-origin-access-control --profile $PROFILE --origin-access-control-config Name=$BUCKET.s3.us-east-1.amazonaws.,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3

  DISTRIBUTION_ID=$(aws cloudfront list-distributions --profile $PROFILE --query "DistributionList.Items[*].{id:Id,origin:Origins.Items[0].Id}[?contains(origin, '$BUCKET')].id" --output text)
  DISTRIBUTION_ARN=$(aws cloudfront get-distribution --profile $PROFILE --id $DISTRIBUTION_ID --query 'Distribution.ARN' --output text)
  S3_POLICY_JSON=./scripts/s3-policy.json
  echo "$( jq '.Statement[].Resource = "arn:aws:s3:::'$BUCKET'/*" | .Statement[].Condition.StringEquals."AWS:SourceArn" = "'$DISTRIBUTION_ARN'"' $S3_POLICY_JSON)" > $S3_POLICY_JSON

  aws s3api put-bucket-policy --profile $PROFILE --bucket $BUCKET --policy file://$S3_POLICY_JSON
fi

# Upload package to S3 Bucket
echo "Uploading 3D Viewer to $BUCKET"
aws s3 sync --profile $PROFILE ./deploy "s3://$BUCKET/$S3_PATH"

# Create invalidation for CloudFront distribution
echo "Creating invalidation for $DISTRIBUTION_ID"
aws cloudfront create-invalidation --profile $PROFILE --distribution-id $DISTRIBUTION_ID --paths "/$BUCKET/*"

echo "Done in $PROFILE"
