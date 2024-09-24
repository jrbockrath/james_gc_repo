#!/bin/bash

set -e

# Set variables
PROJECT_ID="heroic-oven-430715-i1"
CLUSTER_NAME="python-k8s-demo-cluster"
ZONE="us-central1-a"
REGION="us-central1"
DOMAIN="app.swipeleft.ai"
STATIC_IP_NAME="k8s-ingress-static-ip"
EMAIL="your-email@example.com"  # Replace with your email for Let's Encrypt

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

# Connect to the cluster
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE}

# Reserve a static IP address in the us-central1 region if it doesn't exist
if ! gcloud compute addresses describe ${STATIC_IP_NAME} --region=${REGION} &>/dev/null; then
    echo "Reserving a new static IP address in the ${REGION} region..."
    gcloud compute addresses create ${STATIC_IP_NAME} --region=${REGION}
else
    echo "Static IP address already reserved in the ${REGION} region."
fi

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
echo "Waiting for the Ingress controller to be up and reporting an external IP..."
EXTERNAL_IP=""
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [[ -n "$EXTERNAL_IP" ]]; then
        echo "Ingress controller is up and has an external IP: $EXTERNAL_IP"
        break
    fi
    echo "Waiting for external IP... (Attempt $i)"
    sleep 10
done

if [[ -z "$EXTERNAL_IP" ]]; then
    echo "Error: Ingress controller did not receive an external IP after 5 minutes."
    exit 1
fi

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
echo "Creating ClusterIssuer for Let's Encrypt."
cat <<EOF > cluster-issuer.yaml
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

kubectl apply -f cluster-issuer.yaml

# Create Helm chart for the Python application
echo "Creating Helm chart for Python application..."
helm create python-k8s-demo

# Modify the generated Helm chart
echo "Updating Helm chart values..."

cat <<EOF > python-k8s-demo/values.yaml
image:
  repository: gcr.io/${PROJECT_ID}/python-k8s-demo
  tag: v1

service:
  type: LoadBalancer
  port: 80

ingress:
  enabled: true
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
      secretName: k8s-demo-tls

serviceAccount:
  create: false

autoscaling:
  enabled: false  # Set to true if you want to enable autoscaling
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
EOF

# Update the ServiceAccount and HPA templates in the Helm chart
echo "Updating Helm chart templates..."

cat <<EOF > python-k8s-demo/templates/serviceaccount.yaml
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name | default .Release.Name }}
  labels:
    app.kubernetes.io/name: {{ include "python-k8s-demo.name" . }}
    helm.sh/chart: {{ include "python-k8s-demo.chart" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
EOF

cat <<EOF > python-k8s-demo/templates/hpa.yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "python-k8s-demo.fullname" . }}
  labels:
    {{- include "python-k8s-demo.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "python-k8s-demo.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
EOF

# Create the Ingress resource for routing
cat <<EOF > python-k8s-demo/templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: python-k8s-demo
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: python-k8s-demo
            port:
              number: 80
  tls:
  - hosts:
    - ${DOMAIN}
    secretName: k8s-demo-tls
EOF

# Create a small Python program
echo "Creating a small Python program."
cat <<EOF > python-k8s-demo/app.py
from http.server import HTTPServer, BaseHTTPRequestHandler

class SimpleHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'Hello, world from inside the Docker container!')

httpd = HTTPServer(('0.0.0.0', 80), SimpleHandler)
print("Server running on port 80")
httpd.serve_forever()
EOF

echo "Python program has been created."

# Create a Dockerfile for the Python program
echo "Creating a Dockerfile to run the Python program."
cat <<EOF > python-k8s-demo/Dockerfile
FROM python:3.9-slim
WORKDIR /usr/src/app
COPY . .
EXPOSE 80
CMD ["python", "./app.py"]
EOF

echo "Dockerfile has been created."

# Build and push the Docker image
echo "Building and pushing Docker image..."
docker build -t gcr.io/${PROJECT_ID}/python-k8s-demo:v1 ./python-k8s-demo
docker push gcr.io/${PROJECT_ID}/python-k8s-demo:v1

# Deploy the Python application using Helm
echo "Deploying Python application with Helm..."
helm upgrade --install python-k8s-demo ./python-k8s-demo
