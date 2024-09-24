#!/bin/bash

set -e

# Set variables
PROJECT_ID="heroic-oven-430715-i1"
CLUSTER_NAME="python-k8s-demo-cluster"
ZONE="us-central1-a"
STATIC_IP="34.29.20.137"
gcloud config set project heroic-oven-430715-i1

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if necessary commands exist
if ! command_exists gcloud || ! command_exists kubectl; then
    echo "Error: gcloud and kubectl are required. Please install them and try again."
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

# Delete previous deployments and services if they exist
kubectl delete deployment python-k8s-demo --ignore-not-found=true
kubectl delete service k8s-demo-service --ignore-not-found=true

echo "Previous deployments and services have been deleted (if they existed)."

# Create a small Python program
echo "Creating a small Python program."
cat <<EOF > app.py
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
cat <<EOF > Dockerfile
FROM python:3.9-slim
WORKDIR /usr/src/app
COPY . .
EXPOSE 80
CMD ["python", "./app.py"]
EOF

echo "Dockerfile has been created."

# Build and push the Docker image
echo "Building and pushing Docker image..."
docker build -t gcr.io/${PROJECT_ID}/python-k8s-demo:v1 .
docker push gcr.io/${PROJECT_ID}/python-k8s-demo:v1

# Create Kubernetes deployment YAML
echo "Creating Kubernetes deployment."
cat <<EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-k8s-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: python-k8s-demo
  template:
    metadata:
      labels:
        app: python-k8s-demo
    spec:
      containers:
      - name: python-k8s-demo
        image: gcr.io/${PROJECT_ID}/python-k8s-demo:v1
        ports:
        - containerPort: 80
EOF

# Create Kubernetes service YAML with specific IP address
echo "Creating Kubernetes service with specific IP address."
cat <<EOF > service.yaml
apiVersion: v1
kind: Service
metadata:
  name: k8s-demo-service
spec:
  type: LoadBalancer
  loadBalancerIP: ${STATIC_IP}
  selector:
    app: python-k8s-demo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF

echo "Kubernetes deployment and service configurations have been created with the specific IP address: ${STATIC_IP}."

# Apply the Kubernetes deployment and service
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

echo "Kubernetes deployment and service have been applied to the cluster."

# Debug: Check pod status
echo "Checking pod status..."
kubectl get pods

# Debug: Check service status
echo "Checking service status..."
kubectl get services k8s-demo-service

# Debug: Check events
echo "Checking events..."
kubectl get events --sort-by=.metadata.creationTimestamp

# Debug: Check logs of the pod
echo "Checking pod logs..."
POD_NAME=$(kubectl get pods -l app=python-k8s-demo -o jsonpath="{.items[0].metadata.name}")
kubectl logs $POD_NAME

# Debug: Describe the service
echo "Describing the service..."
kubectl describe service k8s-demo-service

# Debug: Check firewall rules
echo "Checking firewall rules..."
gcloud compute firewall-rules list --filter="network:default"

echo "Deployment process complete. The service should now be accessible via IP address: ${STATIC_IP}."
echo "If you're still unable to connect, please review the debug information above."