#!/bin/bash

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

# Set the active GCP project
gcloud config set project ${PROJECT_ID}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if necessary commands exist
if ! command_exists gcloud || ! command_exists kubectl || ! command_exists helm || ! command_exists openssl; then
    echo "Error: gcloud, kubectl, helm, and openssl are required. Please install them and try again."
    exit 1
fi

# Check if the cluster exists
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

# Connect to the existing cluster
echo "Connecting to the existing cluster ${CLUSTER_NAME}..."
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE}

# Function to install cluster-wide components (ingress-nginx, cert-manager)
install_cluster_components() {
    STATIC_IP_NAME="ingress-nginx-static-ip"

    # Reserve a static IP address in the us-central1 region
    echo "Deleting existing static IP address ${STATIC_IP_NAME} in the ${REGION} region..."
    gcloud compute addresses delete ${STATIC_IP_NAME} --region=${REGION} --quiet

    echo "Reserving a new static IP address in the ${REGION} region..."
    gcloud compute addresses create ${STATIC_IP_NAME} --region=${REGION}

    STATIC_IP=$(gcloud compute addresses describe ${STATIC_IP_NAME} --region=${REGION} --format="value(address)")

    # Add Helm repositories
    echo "Adding Helm repositories..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add jetstack https://charts.jetstack.io
    helm repo update

    # Install NGINX Ingress Controller with Helm
    echo "Deploying NGINX Ingress Controller with Helm..."
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --set controller.service.loadBalancerIP=${STATIC_IP} \
        --namespace ingress-nginx --create-namespace

    # Monitor the Ingress controller to ensure it has an external IP
    wait_for_external_ip "ingress-nginx-controller" "ingress-nginx"

    # Install Cert-Manager with Helm
    echo "Deploying Cert-Manager with Helm..."
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager --create-namespace \
        --set installCRDs=true

    # Wait for Cert-Manager to be ready
    echo "Waiting for Cert-Manager to be ready..."
    kubectl wait --namespace cert-manager \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/instance=cert-manager \
      --timeout=300s

    # Create ClusterIssuer for Let's Encrypt
    if ! kubectl get clusterissuer letsencrypt-prod &>/dev/null; then
        echo "Creating ClusterIssuer for Let's Encrypt."
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
    else
        echo "ClusterIssuer 'letsencrypt-prod' already exists."
    fi
}

# Function to wait for service to have an external IP
wait_for_external_ip() {
    SERVICE_NAME=$1
    NAMESPACE=$2
    echo "Waiting for service $SERVICE_NAME to get an external IP..."

    for i in {1..30}; do
        EXTERNAL_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [[ -n "$EXTERNAL_IP" ]]; then
            echo "Service $SERVICE_NAME has an external IP: $EXTERNAL_IP"
            break
        fi
        echo "Waiting for external IP... (Attempt $i)"
        sleep 10
    done

    if [[ -z "$EXTERNAL_IP" ]]; then
        echo "Error: Service $SERVICE_NAME did not receive an external IP after 5 minutes."
        exit 1
    fi
}

# Install cluster-wide components once
install_cluster_components
# Function to deploy an app
deploy_app() {
    APP_NAME=$1
    IMAGE_TAG=$2

    NAMESPACE="${APP_NAME}-namespace"
    DOMAIN="${APP_NAME}.v2.app.swipeleft.ai"
    STATIC_IP_NAME="${APP_NAME}-static-ip"

    # Check if the namespace exists, if not, create it
    if ! kubectl get namespace ${NAMESPACE} &>/dev/null; then
        echo "Namespace ${NAMESPACE} does not exist. Creating it now..."
        kubectl create namespace ${NAMESPACE}
        echo "Namespace ${NAMESPACE} has been created."
    else
        echo "Namespace ${NAMESPACE} already exists."
    fi

    # Reserve a static IP address in the us-central1 region
    echo "Deleting existing static IP address ${STATIC_IP_NAME} in the ${REGION} region..."
    gcloud compute addresses delete ${STATIC_IP_NAME} --region=${REGION} --quiet

    echo "Reserving a new static IP address for ${APP_NAME} in the ${REGION} region..."
    gcloud compute addresses create ${STATIC_IP_NAME} --region=${REGION}

    APP_STATIC_IP=$(gcloud compute addresses describe ${STATIC_IP_NAME} --region=${REGION} --format="value(address)")

    # Create Dockerfile
    echo "Creating Dockerfile for ${APP_NAME}..."
    cat <<EOF > ${APP_NAME}/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

CMD ["python", "app.py"]
EOF

    # Create requirements.txt
    echo "Creating requirements.txt for ${APP_NAME}..."
    cat <<EOF > ${APP_NAME}/requirements.txt
flask
httpx
google-auth
requests
EOF

    # Create app.py
    echo "Creating app.py for ${APP_NAME}..."
    cat <<EOF > ${APP_NAME}/app.py
import os
import httpx
import google.auth
from google.auth.transport.requests import Request
from flask import Flask, request, jsonify

app = Flask(__name__)

PROJECT_ID = "${PROJECT_ID}"
LOCATION = "${LOCATION}"
MODEL_NAME = "${MODEL_NAME}"
MODEL_VERSION = "${MODEL_VERSION}"

def get_credentials():
    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    credentials.refresh(Request())
    return credentials.token

def build_endpoint_url(streaming: bool = False):
    base_url = f"https://{LOCATION}-aiplatform.googleapis.com/v1/"
    project_fragment = f"projects/{PROJECT_ID}"
    location_fragment = f"locations/{LOCATION}"
    specifier = "streamGenerateContent" if streaming else "generateContent"
    model_fragment = f"publishers/google/models/{MODEL_NAME}"
    url = f"{base_url}{'/'.join([project_fragment, location_fragment, model_fragment])}:{specifier}"
    return url

@app.route('/', methods=['GET'])
def home():
    return "Gemini 1.5 Pro Prediction Service"

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.json
        prompt = data.get('prompt', '')

        access_token = get_credentials()
        url = build_endpoint_url(streaming=False)

        headers = {
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
        }

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.9,
                "topP": 1,
                "topK": 1,
                "maxOutputTokens": 2048,
            },
        }

        with httpx.Client() as client:
            resp = client.post(url, json=payload, headers=headers, timeout=None)
            response_data = resp.json()

        generated_content = response_data['candidates'][0]['content']['parts'][0]['text']
        return jsonify({"generated_content": generated_content})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)
EOF

    # Build and push the Docker image
    echo "Building and pushing Docker image for ${APP_NAME}..."
    docker build --no-cache -t gcr.io/${PROJECT_ID}/${APP_NAME}:${IMAGE_TAG} ./${APP_NAME}
    docker push gcr.io/${PROJECT_ID}/${APP_NAME}:${IMAGE_TAG}

    # Deploy the application using Helm
    echo "Deploying ${APP_NAME} with Helm..."
    helm upgrade --install ${APP_NAME} ./${APP_NAME} --namespace ${NAMESPACE}

    # Wait for the service to have an external IP
    wait_for_external_ip "${APP_NAME}" "${NAMESPACE}"
}

# Deploy the applications
deploy_app "app1" "v1"

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

# Final message
echo "All applications and services have been successfully deployed and are operational."
