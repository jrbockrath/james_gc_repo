#!/bin/bash

set -e

# Set variables
PROJECT_ID="heroic-oven-430715-i1"
CLUSTER_NAME="python-k8s-demo-cluster"
ZONE="us-central1-a"
GLOBAL_IP="34.28.154.190"
BASE_DIR=$(dirname "$0")

# Define paths
PYTHON_APP_DIR="${BASE_DIR}/python-k8s-demo/python-app"
RUST_APP_DIR="${BASE_DIR}/python-k8s-demo/rust-prime-app"
PYTHON_DEPLOYMENT_FILE="${BASE_DIR}/python-k8s-demo/python-deployment.yaml"
RUST_DEPLOYMENT_FILE="${BASE_DIR}/python-k8s-demo/rust-deployment.yaml"
PYTHON_SERVICE_FILE="${BASE_DIR}/python-k8s-demo/python-service.yaml"
RUST_SERVICE_FILE="${BASE_DIR}/python-k8s-demo/rust-service.yaml"
INGRESS_FILE="${BASE_DIR}/python-k8s-demo/ingress.yaml"

# Create project structure if it doesn't exist
mkdir -p "$PYTHON_APP_DIR"
mkdir -p "$RUST_APP_DIR/src"

# Create Python application if it doesn't exist
if [ ! -f "${PYTHON_APP_DIR}/app.py" ]; then
  cat << EOF > "${PYTHON_APP_DIR}/app.py"
from flask import Flask, request
import time

app = Flask(__name__)

def is_prime(n):
    if n < 2:
        return False
    for i in range(2, int(n ** 0.5) + 1):
        if n % i == 0:
            return False
    return True

def count_primes(limit):
    count = 0
    for num in range(2, limit + 1):
        if is_prime(num):
            count += 1
    return count

@app.route('/')
def hello():
    return "Hello from Kubernetes!"

@app.route('/prime')
def prime():
    limit = request.args.get('limit', default=100000, type=int)
    start_time = time.time()
    result = count_primes(limit)
    end_time = time.time()
    execution_time = end_time - start_time
    return f"Number of primes up to {limit}: {result}. Calculated in {execution_time:.2f} seconds."

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
EOF
fi

# Create Python Dockerfile if it doesn't exist
if [ ! -f "${PYTHON_APP_DIR}/Dockerfile" ]; then
  cat << EOF > "${PYTHON_APP_DIR}/Dockerfile"
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]
EOF
fi

# Create Python requirements.txt if it doesn't exist
if [ ! -f "${PYTHON_APP_DIR}/requirements.txt" ]; then
  cat << EOF > "${PYTHON_APP_DIR}/requirements.txt"
flask==2.0.1
werkzeug==2.0.1
EOF
fi

# Create Rust application if it doesn't exist
if [ ! -f "${RUST_APP_DIR}/src/main.rs" ]; then
  cat << EOF > "${RUST_APP_DIR}/src/main.rs"
use actix_web::{get, web, App, HttpResponse, HttpServer, Responder};
use std::time::Instant;

fn is_prime(n: u64) -> bool {
    if n < 2 {
        return false;
    }
    for i in 2..=(n as f64).sqrt() as u64 {
        if n % i == 0 {
            return false;
        }
    }
    true
}

fn count_primes(limit: u64) -> u64 {
    (2..=limit).filter(|&n| is_prime(n)).count() as u64
}

#[get("/")]
async fn hello() -> impl Responder {
    HttpResponse::Ok().body("Hello from Kubernetes!")
}

#[get("/prime")]
async fn prime(web::Query(info): web::Query<std::collections::HashMap<String, u64>>) -> impl Responder {
    let limit = info.get("limit").cloned().unwrap_or(100000);
    let start = Instant::now();
    let result = count_primes(limit);
    let duration = start.elapsed();
    HttpResponse::Ok().body(format!(
        "Number of primes up to {}: {}. Calculated in {:.2} seconds.",
        limit,
        result,
        duration.as_secs_f64()
    ))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);
    
    println!("Starting server at: {}", addr);

    HttpServer::new(|| App::new().service(hello).service(prime))
        .bind(addr)?
        .run()
        .await
}
EOF
fi

# Create Rust Cargo.toml if it doesn't exist
if [ ! -f "${RUST_APP_DIR}/Cargo.toml}" ]; then
  cat << EOF > "${RUST_APP_DIR}/Cargo.toml"
[package]
name = "rust-prime-app"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4.3.1"
EOF
fi

# Create Rust Dockerfile if it doesn't exist
if [ ! -f "${RUST_APP_DIR}/Dockerfile}" ]; then
  cat << EOF > "${RUST_APP_DIR}/Dockerfile"
FROM rust:1.72-alpine as builder
RUN apk add --no-cache musl-dev
WORKDIR /usr/src/app
COPY . .
RUN cargo build --release

FROM alpine:latest
COPY --from=builder /usr/src/app/target/release/rust-prime-app /usr/local/bin/rust-prime-app
CMD ["rust-prime-app"]
EOF
fi

# Check if the Kubernetes cluster exists
if ! gcloud container clusters describe ${CLUSTER_NAME} --zone=${ZONE} &> /dev/null; then
  # Create GKE cluster
  gcloud container clusters create ${CLUSTER_NAME} --num-nodes=3 --zone=${ZONE}
else
  echo "GKE cluster ${CLUSTER_NAME} already exists. Skipping creation."
fi

# Get credentials for the cluster
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone=${ZONE}

# Build and push Docker images
docker build -t gcr.io/${PROJECT_ID}/python-k8s-demo:v1 "${PYTHON_APP_DIR}"
docker push gcr.io/${PROJECT_ID}/python-k8s-demo:v1

docker build -t gcr.io/${PROJECT_ID}/rust-k8s-demo:v1 "${RUST_APP_DIR}"
docker push gcr.io/${PROJECT_ID}/rust-k8s-demo:v1

# Ensure Python deployment file exists
if [ ! -f "${PYTHON_DEPLOYMENT_FILE}" ]; then
  cat << EOF > "${PYTHON_DEPLOYMENT_FILE}"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-k8s-demo
  labels:
    app: k8s-demo
    version: python
spec:
  replicas: 1
  selector:
    matchLabels:
      app: k8s-demo
      version: python
  template:
    metadata:
      labels:
        app: k8s-demo
        version: python
    spec:
      containers:
      - name: python-k8s-demo
        image: gcr.io/${PROJECT_ID}/python-k8s-demo:v1
        ports:
        - containerPort: 8080
EOF
fi

# Ensure Rust deployment file exists
if [ ! -f "${RUST_DEPLOYMENT_FILE}" ]; then
  cat << EOF > "${RUST_DEPLOYMENT_FILE}"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rust-k8s-demo
  labels:
    app: k8s-demo
    version: rust
spec:
  replicas: 1
  selector:
    matchLabels:
      app: k8s-demo
      version: rust
  template:
    metadata:
      labels:
        app: k8s-demo
        version: rust
    spec:
      containers:
      - name: rust-k8s-demo
        image: gcr.io/${PROJECT_ID}/rust-k8s-demo:v1
        ports:
        - containerPort: 8080
EOF
fi

# Ensure Python service file exists
if [ ! -f "${PYTHON_SERVICE_FILE}" ]; then
  cat << EOF > "${PYTHON_SERVICE_FILE}"
apiVersion: v1
kind: Service
metadata:
  name: python-k8s-demo
spec:
  selector:
    app: k8s-demo
    version: python
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
EOF
fi

# Ensure Rust service file exists
if [ ! -f "${RUST_SERVICE_FILE}" ]; then
  cat << EOF > "${RUST_SERVICE_FILE}"
apiVersion: v1
kind: Service
metadata:
  name: rust-k8s-demo
spec:
  selector:
    app: k8s-demo
    version: rust
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
EOF
fi

# Deploy services to Kubernetes
kubectl apply -f "${PYTHON_SERVICE_FILE}"
kubectl apply -f "${RUST_SERVICE_FILE}"

# Create Ingress resource with global IP
if [ ! -f "${INGRESS_FILE}" ]; then
  cat << EOF > "${INGRESS_FILE}"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: k8s-demo-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "global-static-ip"
spec:
  rules:
  - http:
      paths:
      - path: /python
        pathType: Prefix
        backend:
          service:
            name: python-k8s-demo
            port:
              number: 80
      - path: /rust
        pathType: Prefix
        backend:
          service:
            name: rust-k8s-demo
            port:
              number: 80
EOF
fi

# Deploy Ingress resource to Kubernetes
kubectl apply -f "${INGRESS_FILE}"

# Check if Ingress Controller is installed
if ! kubectl get pods -n ingress-nginx | grep -q 'ingress-nginx-controller'; then
  echo "Ingress controller not found. Installing NGINX Ingress Controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
fi

echo "Deployment complete! You can access the services via the global IP: http://${GLOBAL_IP}/python or http://${GLOBAL_IP}/rust"
