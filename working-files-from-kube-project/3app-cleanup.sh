#!/bin/bash

set -e

# Set namespaces and regions
NAMESPACES=("app1-namespace" "app2-namespace" "app3-namespace")  # Namespaces for your apps
INGRESS_NAMESPACE="ingress-nginx"
CERT_MANAGER_NAMESPACE="cert-manager"
REGION="us-central1"

# Delete Helm releases for the applications
for NAMESPACE in "${NAMESPACES[@]}"; do
  APP_NAME="${NAMESPACE%-namespace}"  # Derive app name from namespace
  echo "Deleting Helm release for ${APP_NAME} in namespace ${NAMESPACE}..."
  helm uninstall ${APP_NAME} --namespace ${NAMESPACE} || echo "Release for ${APP_NAME} not found in namespace ${NAMESPACE}."
  
  echo "Deleting namespace ${NAMESPACE}..."
  kubectl delete namespace ${NAMESPACE} --ignore-not-found || echo "Namespace ${NAMESPACE} not found."
done

# Delete the Helm release for Cert-Manager
echo "Deleting Helm release for Cert-Manager..."
helm uninstall cert-manager --namespace ${CERT_MANAGER_NAMESPACE} || echo "Cert-Manager release not found."

# Delete any lingering Cert-Manager CRDs
echo "Deleting lingering Cert-Manager CRDs..."
kubectl delete crd certificaterequests.cert-manager.io \
  certificates.cert-manager.io \
  challenges.acme.cert-manager.io \
  clusterissuers.cert-manager.io \
  issuers.cert-manager.io \
  orders.acme.cert-manager.io --ignore-not-found || echo "Some Cert-Manager CRDs not found or already deleted."

# Delete the Helm release for NGINX Ingress Controller
echo "Deleting Helm release for NGINX Ingress Controller..."
helm uninstall ingress-nginx --namespace ${INGRESS_NAMESPACE} || echo "NGINX Ingress Controller release not found."

# Delete the namespace for Cert-Manager
echo "Deleting namespace ${CERT_MANAGER_NAMESPACE}..."
kubectl delete namespace ${CERT_MANAGER_NAMESPACE} --ignore-not-found || echo "Namespace ${CERT_MANAGER_NAMESPACE} not found."

# Delete the namespace for NGINX Ingress Controller
echo "Deleting namespace ${INGRESS_NAMESPACE}..."
kubectl delete namespace ${INGRESS_NAMESPACE} --ignore-not-found || echo "Namespace ${INGRESS_NAMESPACE} not found."

# Delete static IP addresses for the apps
for APP_NAME in "app1" "app2" "app3"; do
  STATIC_IP_NAME="${APP_NAME}-static-ip"
  echo "Deleting static IP address ${STATIC_IP_NAME} in region ${REGION}..."
  gcloud compute addresses delete ${STATIC_IP_NAME} --region=${REGION} --quiet || echo "Static IP address ${STATIC_IP_NAME} not found."
done

# Optionally, remove the GCR Docker images (uncomment if needed)
# PROJECT_ID="your-project-id"
# for APP_NAME in "app1" "app2" "app3"; do
#   echo "Deleting Docker image for ${APP_NAME} from GCR..."
#   gcloud container images delete gcr.io/${PROJECT_ID}/${APP_NAME}:v1 --quiet || echo "Docker image for ${APP_NAME} not found."
# done

echo "Cleanup complete. All resources except the Kubernetes cluster have been removed."
