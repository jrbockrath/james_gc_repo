#!/bin/bash

set -e

# Set environment variables
export PROJECT_ID="heroic-oven-430715-i1"
export CLUSTER_NAME="python-k8s-demo-cluster-v2"
export ZONE="us-central1-a"
export REGION="us-central1"
export EMAIL="james@swipeleft.ai"
export LOCATION="us-central1"
export MODEL_NAME="gemini-1.5-pro"
export MODEL_VERSION="001"

# Set default app parameters
DEFAULT_APP_NAME="app1"
DEFAULT_IMAGE_TAG="v1"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if necessary commands exist
for cmd in gcloud kubectl helm docker; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Set the active GCP project
gcloud config set project ${PROJECT_ID}

# Ensure cluster exists
ensure_cluster_exists() {
    if ! gcloud container clusters describe ${CLUSTER_NAME} --zone=${ZONE} &>/dev/null; then
        echo "Cluster ${CLUSTER_NAME} does not exist. Creating it now..."
        gcloud container clusters create ${CLUSTER_NAME} \
            --project=${PROJECT_ID} \
            --zone=${ZONE} \
            --num-nodes=3 \
            --machine-type=e2-medium
        echo "Cluster ${CLUSTER_NAME} has been created."
    else
        echo "Cluster ${CLUSTER_NAME} already exists."
    fi

    # Connect to the cluster
    gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE}
}

# Install cluster-wide components
install_cluster_components() {
    STATIC_IP_NAME="ingress-nginx-static-ip"

    # Reserve a static IP address
    gcloud compute addresses create ${STATIC_IP_NAME} --region=${REGION} || true
    STATIC_IP=$(gcloud compute addresses describe ${STATIC_IP_NAME} --region=${REGION} --format="value(address)")

    # Install NGINX Ingress Controller
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --set controller.service.loadBalancerIP=${STATIC_IP} \
        --namespace ingress-nginx --create-namespace

    # Install Cert-Manager
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager --create-namespace \
        --set installCRDs=true

    # Wait for Cert-Manager to be ready
    kubectl wait --namespace cert-manager \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/instance=cert-manager \
      --timeout=300s

    # Create ClusterIssuer for Let's Encrypt
    if ! kubectl get clusterissuer letsencrypt-prod &>/dev/null; then
        cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    fi
}

build_and_push_image() {
    APP_NAME=$1
    IMAGE_TAG=$2

    echo "Building Docker image for ${APP_NAME}..."
    docker build -t gcr.io/${PROJECT_ID}/${APP_NAME}:${IMAGE_TAG} -f apps/${APP_NAME}/docker/Dockerfile .
    
    echo "Pushing Docker image to Google Container Registry..."
    docker push gcr.io/${PROJECT_ID}/${APP_NAME}:${IMAGE_TAG}
}

# Deploy app using Helm
deploy_app() {
    APP_NAME=$1
    IMAGE_TAG=$2
    NAMESPACE="${APP_NAME}-namespace"

    # Create namespace if it doesn't exist
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

    # Fetch Cronofy secrets from Secret Manager
    CRONOFY_CLIENT_ID=$(gcloud secrets versions access latest --secret="cronofy-client-id")
    CRONOFY_CLIENT_SECRET=$(gcloud secrets versions access latest --secret="cronofy-client-secret")

    # Update values.yaml with the correct image
    sed -i "s|repository:.*|repository: gcr.io/${PROJECT_ID}/${APP_NAME}|g" apps/${APP_NAME}/helm/values.yaml
    sed -i "s|tag:.*|tag: ${IMAGE_TAG}|g" apps/${APP_NAME}/helm/values.yaml

    # Deploy the application using Helm
    helm upgrade --install ${APP_NAME} ./apps/${APP_NAME}/helm \
      --namespace ${NAMESPACE} \
      --set cronofySecrets.clientId=${CRONOFY_CLIENT_ID} \
      --set cronofySecrets.clientSecret=${CRONOFY_CLIENT_SECRET} \
      --set env.PROJECT_ID=${PROJECT_ID} \
      --set env.LOCATION=${LOCATION} \
      --set env.MODEL_NAME=${MODEL_NAME} \
      --set env.MODEL_VERSION=${MODEL_VERSION}

    # Wait for deployment to be ready
    kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=300s

    # Get the external IP
    EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Application ${APP_NAME} is accessible via: http://${EXTERNAL_IP}"
}

# Main execution
ensure_cluster_exists
install_cluster_components
build_and_push_image ${DEFAULT_APP_NAME} ${DEFAULT_IMAGE_TAG}
deploy_app ${DEFAULT_APP_NAME} ${DEFAULT_IMAGE_TAG}

echo "Deployment completed successfully."

# Define the list of apps to process; currently only app1 is included
APPS=("app1") # Add more apps later as needed, e.g., ("app1" "app2" "app3")

# Function to recreate service for an app
recreate_service() {
    local APP_NAME=$1
    local NAMESPACE="${APP_NAME}-namespace"
    
    echo "Recreating service for ${APP_NAME}..."
    kubectl delete svc ${APP_NAME} -n ${NAMESPACE}
    kubectl expose deployment ${APP_NAME} --type=LoadBalancer --name=${APP_NAME} -n ${NAMESPACE}

    echo "Waiting for service ${APP_NAME} to be ready..."
    while true; do
        ENDPOINTS=$(kubectl get endpoints ${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)
        if [ -n "${ENDPOINTS}" ]; then
            echo "Service ${APP_NAME} is ready with endpoints: ${ENDPOINTS}"
            break
        else
            echo "Waiting for service ${APP_NAME} to become ready..."
            sleep 10
        fi
    done

    echo "Checking for external IP for ${APP_NAME}..."
    for i in {1..30}; do # Limit to 5 minutes (30 attempts with 10 seconds each)
        EXTERNAL_IP=$(kubectl get svc ${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "${EXTERNAL_IP}" ]; then
            echo "Service ${APP_NAME} is accessible via external IP: ${EXTERNAL_IP}"
            break
        else
            echo "Waiting for external IP for ${APP_NAME}... (Attempt $i)"
            sleep 10
        fi
    done

    if [ -z "${EXTERNAL_IP}" ]; then
        echo "Error: Service ${APP_NAME} did not receive an external IP after 5 minutes."
        exit 1
    fi
}

# Loop through the list of apps and recreate services; currently only processes app1
for APP_NAME in "${APPS[@]}"; do
    recreate_service "${APP_NAME}"
done # Close the loop properly

# Final message
echo "All applications and services have been successfully deployed and are operational."

