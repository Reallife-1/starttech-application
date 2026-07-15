#!/bin/bash
set -euo pipefail

AWS_REGION="us-east-1"
EKS_CLUSTER_NAME="starttech-cluster"

echo "Updating kubeconfig for EKS..."
aws eks update-kubeconfig --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}"

echo "Current rollout history for backend-api:"
kubectl rollout history deployment/backend-api

echo "Rolling back to previous revision..."
kubectl rollout undo deployment/backend-api

echo "Verifying rollback status..."
kubectl rollout status deployment/backend-api

echo "Rollback complete. Current pods:"
kubectl get pods -l app=backend-api