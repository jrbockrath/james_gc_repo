#!/bin/bash

export PROJECT_ID="heroic-oven-430715-i1"
export CLUSTER_NAME="python-k8s-demo-cluster-v2"
export ZONE="us-central1-a"
export REGION="us-central1"
export EMAIL="james@swipeleft.ai"

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

    # Create Helm chart for the Python application
    echo "Creating Helm chart for ${APP_NAME}..."
    helm create ${APP_NAME}

    # Copy app.py to the application directory
    echo "Copying app.py to ${APP_NAME} directory..."
    cp app.py ${APP_NAME}/

    # Update values.yaml with environment variables
    cat <<EOF > ${APP_NAME}/values.yaml
app:
  name: ${APP_NAME}
  tag: ${IMAGE_TAG}

image:
  repository: gcr.io/${PROJECT_ID}/${APP_NAME}
  tag: ${IMAGE_TAG}

service:
  type: LoadBalancer
  port: 80

ingress:
  enabled: true
  className: "nginx"  # Set the IngressClassName here
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: ${DOMAIN}
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - hosts:
      - ${DOMAIN}
      secretName: ${APP_NAME}-tls

serviceAccount:
  create: false

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 100
  targetCPUUtilizationPercentage: 50
EOF

    # Update deployment.yaml to include environment variables and correct labels
    cat <<EOF > ${APP_NAME}/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app.kubernetes.io/instance: {{ .Chart.Name }}
    app.kubernetes.io/name: {{ .Chart.Name }}
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/instance: {{ .Chart.Name }}
      app.kubernetes.io/name: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: {{ .Chart.Name }}
        app.kubernetes.io/name: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 80
          env:
            - name: APP_NAME
              value: "{{ .Values.app.name }}"
            - name: IMAGE_TAG
              value: "{{ .Values.app.tag }}"
EOF

    # Update autoscaling.yaml to use autoscaling/v1
    cat <<EOF > ${APP_NAME}/templates/hpa.yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Chart.Name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Chart.Name }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  targetCPUUtilizationPercentage: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
EOF

    # Build and push the Docker image
    echo "Building and pushing Docker image for ${APP_NAME}..."
    docker build -t gcr.io/${PROJECT_ID}/${APP_NAME}:${IMAGE_TAG} ./${APP_NAME}
    docker push gcr.io/${PROJECT_ID}/${APP_NAME}:${IMAGE_TAG}

    # Deploy the application using Helm
    echo "Deploying ${APP_NAME} with Helm..."
    helm upgrade --install ${APP_NAME} ./${APP_NAME} --namespace ${NAMESPACE}

    # Wait for the service to have an external IP
    wait_for_external_ip "${APP_NAME}" "${NAMESPACE}"
}

# Install cluster-wide components once
install_cluster_components

# Example deployment of multiple apps
deploy_app "app1" "v1"
deploy_app "app2" "v1"
deploy_app "app3" "v1"

# Recreate services to ensure proper configuration
for APP_NAME in "app1" "app2" "app3"; do
    NAMESPACE="${APP_NAME}-namespace"
    echo "Recreating service for ${APP_NAME}..."
    kubectl delete svc ${APP_NAME} -n ${NAMESPACE}
    kubectl expose deployment ${APP_NAME} --type=LoadBalancer --name=${APP_NAME} -n ${NAMESPACE}

    # Monitor the service until the endpoints are ready
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

    # Verify that the service has an external IP
    echo "Checking for external IP for ${APP_NAME}..."
    while true; do
        EXTERNAL_IP=$(kubectl get svc ${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "${EXTERNAL_IP}" ]; then
            echo "Service ${APP_NAME} is accessible via external IP: ${EXTERNAL_IP}"
            break
        else
            echo "Waiting for external IP for ${APP_NAME}..."
            sleep 10
        fi
    done
done

# Final message
echo "All applications and services have been successfully deployed and are operational."
