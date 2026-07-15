#!/bin/bash
set -euo pipefail

AWS_REGION="us-east-1"
ECR_REPOSITORY="starttech-backend-api"
EKS_CLUSTER_NAME="starttech-cluster"
IMAGE_TAG=$(git rev-parse --short HEAD)

echo "Logging in to Amazon ECR..."
ECR_REGISTRY=$(aws ecr describe-repositories --repository-names "${ECR_REPOSITORY}" --region "${AWS_REGION}" --query "repositories[0].repositoryUri" --output text | cut -d'/' -f1)
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "Building Docker image..."
cd "$(dirname "$0")/../backend"
docker build -t "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}" .

echo "Pushing image to ECR..."
docker push "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

echo "Updating kubeconfig for EKS..."
aws eks update-kubeconfig --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}"

echo "Updating deployment manifest with new image tag..."
cd ../k8s
sed -i "s|image:.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}|g" deployment.yaml

echo "Applying Kubernetes manifests..."
kubectl apply -f .

echo "Verifying rollout..."
kubectl rollout status deployment/backend-api

echo "Backend deployment complete. Image tag: ${IMAGE_TAG}"