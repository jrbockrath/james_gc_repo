#!/bin/bash

set -e

# Set variables
PROJECT_ID="heroic-oven-430715-i1"
CLUSTER_NAME="python-k8s-demo-cluster"
ZONE="us-central1-a"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if necessary commands exist
if ! command_exists gcloud || ! command_exists kubectl; then
    echo "Error: gcloud and kubectl are required. Please install them and try again."
    exit 1
fi


# Connect to the cluster (this will fail if the cluster doesn't exist, but that's okay)
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE} || true

# Delete deployments and services if they exist
kubectl delete deployment python-k8s-demo --ignore-not-found=true
kubectl delete deployment rust-k8s-demo --ignore-not-found=true
kubectl delete service k8s-demo-service --ignore-not-found=true

echo "Deployments and services have been deleted (if they existed)."

# Delete the entire cluster
gcloud container clusters delete ${CLUSTER_NAME} --zone=${ZONE} --quiet

echo "Cluster ${CLUSTER_NAME} has been deleted."

# Remove Docker images from Container Registry
gcloud container images delete gcr.io/${PROJECT_ID}/python-k8s-demo:v1 --quiet || true
gcloud container images delete gcr.io/${PROJECT_ID}/rust-k8s-demo:v1 --quiet || true

echo "Docker images have been removed from Container Registry (if they existed)."

echo "Shutdown process complete. All resources related to this project have been removed."