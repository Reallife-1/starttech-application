#!/bin/bash
set -euo pipefail

AWS_REGION="us-east-1"

if [ -z "${FRONTEND_BUCKET_NAME:-}" ]; then
  echo "Error: FRONTEND_BUCKET_NAME environment variable is not set."
  exit 1
fi

if [ -z "${CLOUDFRONT_DISTRIBUTION_ID:-}" ]; then
  echo "Error: CLOUDFRONT_DISTRIBUTION_ID environment variable is not set."
  exit 1
fi

echo "Installing dependencies..."
cd "$(dirname "$0")/../frontend"
npm ci

echo "Running security audit..."
npm audit --audit-level=high || true

echo "Building frontend..."
npm run build

echo "Syncing build output to S3..."
aws s3 sync dist "s3://${FRONTEND_BUCKET_NAME}" --delete --region "${AWS_REGION}"

echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id "${CLOUDFRONT_DISTRIBUTION_ID}" --paths "/*"

echo "Frontend deployment complete."