./system-debug.sh 
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
ls
git archive 7cba62e19a853f5f845e59166aebd6f2f638e456 | tar -x -C .
./scripts/run.sh 
./scripts/run.sh
ls
chmod +x update-app-py.sh 
update-app-py.sh
ls
./update-app-py.sh 
./scripts/run.sh
./update-app-py.sh 
./scripts/run.sh
./update-app-py.sh 
./scripts/run.sh
./update-app-py.sh 
./scripts/run.sh
cd container_land/
cd swsystem
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
curl -L -o swsystem.zip https://github.com/jrbockrath/swsystem/archive/7cba62e19a853f5f845e59166aebd6f2f638e456.zip
unzip swsystem.zip
git init swsystem && cd swsystem
git remote add origin https://github.com/jrbockrath/swsystem.git
git fetch origin 7cba62e19a853f5f845e59166aebd6f2f638e456
git checkout FETCH_HEAD
./scripts/run.sh 
ls
cd container_land/
cd swsystem
ls
chmod +x ./scripts/redeploy-app.sh 
./scripts//redeploy-app.sh 
cd container_land/
cd swsystem
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
docker build -t gcr.io/your-project-id/llama-summarizer:latest .
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
chmod +x ./container_land/swsystem/scripts/mini-cleanup.sh 
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
export FLASK_ENV=development
flask run
export FLASK_ENV=development  # Set the environment to development
export FLASK_APP=app.py       # Set the entry point for Flask
flask run                     # Start the Flask application
export FLASK_APP=./apps/app1/src/app.py
export FLASK_ENV=development  # Set the environment to development
export FLASK_APP=app.py       # Ensure this matches your file name
flask run                     # Start the Flask application
export FLASK_APP=app.py       # Ensure this matches your file name
flask run
export FLASK_APP=./apps/app1/src/app.py
flask run
pip install -r requirements.txt
pip install -r ./apps/app1/docker/requirements.txt
flask run
cd container_land/
cd swsystem
ls
./scripts/run.sh 
cd container_land/
cd swsystem
ls
git fetch origin 7cba62e19a853f5f845e59166aebd6f2f638e456
ls
git checkout 7cba62e19a853f5f845e59166aebd6f2f638e456 -- .
ls
./scripts/run.sh 
kubectl get pods -n <namespace>
kubectl get pods -n app1-namespace
kubectl logs app1-5778d57555-2qr9p -n app1-namespace
helm upgrade --install {{ .Chart.Name }} ./apps/app1/helm -n app1-namespace
ls
cd container_land/
ls
cd swsystem
ls
./scripts/mini-cleanup.sh 
kubectl get pods -n <namespace>
kubectl get pods -n app1-namespace
kubectl logs app1-78ff57b7d4-b8csn -n app1-namespace
kubectl describe pod app1-78ff57b7d4-b8csn -n app1-namespace
docker build --no-cache -t gcr.io/heroic-oven-430715-i1/app1:v1 -f apps/app1/docker/Dockerfile .
curl http://localhost:5000
kubectl get svc -n app1-namespace
curl http://34.68.14.238:5000
kubectl describe svc app1 -n app1-namespace
app.kubernetes.io/instance=app1,app.kubernetes.io/name=app1
kubectl get pods -n app1-namespace --show-labels
kubectl logs app1-78ff57b7d4-b8csn -n app1-namespace
kubectl describe pod app1-78ff57b7d4-b8csn -n app1-namespace
docker run -it --rm gcr.io/heroic-oven-430715-i1/app1:v1 /bin/sh
ls
./scripts/cleanup-all-except-clusters.sh 
kubectl get pods -n app1-namespace --show-labels
kubectl logs app1-78ff57b7d4-6fvhx -n app1-namespace
kubectl exec -it app1-78ff57b7d4-6fvhx -n app1-namespace -- /bin/sh
kubectl exec -it app1-78ff57b7d4-6fvhx -n app1-namespace -- /bin/sh
ls
cd container_land/
ls
cd swsystem
git fetch origin 7cba62e19a853f5f845e59166aebd6f2f638e456
git checkout 7cba62e19a853f5f845e59166aebd6f2f638e456 -- .
ls
ENDPOINT=us-central1-aiplatform.googleapis.com
REGION=us-central1
PROJECT_ID="heroic-oven-430715-i1"
curl   -X POST   -H "Authorization: Bearer $(gcloud auth print-access-token)"   -H "Content-Type: application/json" https://${ENDPOINT}/v1beta1/projects/${PROJECT_ID}/locations/${REGION}/endpoints/openapi/chat/completions   -d '{"model":"meta/llama3-405b-instruct-maas", "stream":true, "messages":[{"role": "user", "content": "Summer travel plan to Paris"}]}'
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
kubectl get pods -n app1-namespace
curl 34.41.115.187
kubectl get svc -n app1-namespace
kubectl exec -it <pod-name> -n app1-namespace -- curl http://34.118.231.38
kubectl get pods -n app1-namespace
kubectl exec -it app1-5778d57555-2ckzj -n app1-namespace -- curl http://34.118.231.38
kubectl run curlpod --image=curlimages/curl -n app1-namespace --restart=Never -- sleep 3600
kubectl exec -it curlpod -n app1-namespace -- curl http://34.118.231.38
kubectl get endpoints app1 -n app1-namespace
kubectl exec -it curlpod -n app1-namespace -- curl http://10.48.0.13:80
kubectl exec -it curlpod -n app1-namespace -- curl http://10.48.1.16:80
kubectl exec -it curlpod -n app1-namespace -- curl http://10.48.2.34:80
kubectl describe pod app1-5778d57555-2ckzj -n app1-namespace
kubectl exec -it app1-5778d57555-2ckzj -n app1-namespace -- /bin/sh
# kubectl exec -it app1-5778d57555-2ckzj -n app1-namespace -- ss -tuln
/bin/sh: 4: kubectl: not found
kubectl exec -it app1-5778d57555-2ckzj -n app1-namespace -- ss -tuln
kubectl exec -it app1-5778d57555-2ckzj -n app1-namespace -- cat /proc/net/tcp
ls
tar -czvf swsystem.tar.gz swsystem/
cd ..
tar -czvf swsystem.tar.gz swsystem/
tar -tzvf swsystem.tar.gz
cloudshell download swsystem.tar.gz
./sc
ls
cd c
ls
cd swsystem
ls
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
ls
git fetch origin 7cba62e19a853f5f845e59166aebd6f2f638e456
git checkout 7cba62e19a853f5f845e59166aebd6f2f638e456 -- .
ls
./scripts/run.sh 
curl 104.197.213.31
kubectl get pods -n app1-namespace
kubectl logs <pod-name> -n app1-namespace
kubectl describe pod <pod-name> -n app1-namespace
kubectl get svc -n app1-namespace
kubectl get events -n app1-namespace
kubectl get svc -n app1-namespace
kubectl describe svc app1 -n app1-namespace
kubectl get endpoints -n app1-namespace
kubectl get pods -n app1-namespace
kubectl describe svc app1 -n app1-namespace
kubectl describe ingress app1 -n app1-namespace
kubectl logs -l app.kubernetes.io/name=ingress-nginx -n kube-system
gcloud compute forwarding-rules list
gcloud compute forwarding-rules describe a523efdfdbf144c7483bc77ea0755792 --region us-central1
gcloud compute forwarding-rules describe a6a52af5eb0724e37a49e50b091594bd --region us-central1
gcloud compute target-pools describe a523efdfdbf144c7483bc77ea0755792 --region us-central1
gcloud compute target-pools describe a6a52af5eb0724e37a49e50b091594bd --region us-central1
gcloud compute health-checks describe k8s-9f1bba71989fb3e4-node
gcloud compute backend-services list --global
gcloud compute backend-services describe <backend-service-name> --global
gcloud compute health-checks list
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh && ./scripts/run.sh
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh && ./scripts/run.sh
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d '{
  "contents": [{"parts": [{"text": "happy days"}]}],
  "generationConfig": {
    "temperature": 0.9,
    "topP": 1,
    "topK": 1,
    "maxOutputTokens": 2048
  }
}' "https://us-central1-aiplatform.googleapis.com/v1/projects/heroic-oven-430715-i1/locations/us-central1/publishers/google/models/gemini-1.5-pro:generateContent"
./scripts/cleanup-all-except-clusters.sh && ./scripts/run.sh
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d '{
  "contents": [{"parts": [{"text": "happy days", "role": "user"}]}],
  "generationConfig": {
    "temperature": 0.9,
    "topP": 1,
    "topK": 1,
    "maxOutputTokens": 2048
  }
}' "https://us-central1-aiplatform.googleapis.com/v1/projects/heroic-oven-430715-i1/locations/us-central1/publishers/google/models/gemini-1.5-pro:generateContent"
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d '{
  "contents": [{"parts": [{"text": "happy days"}]}],
  "generationConfig": {
    "temperature": 0.9,
    "topP": 1,
    "topK": 1,
    "maxOutputTokens": 2048
  }
}' "https://us-central1-aiplatform.googleapis.com/v1/projects/heroic-oven-430715-i1/locations/us-central1/publishers/google/models/gemini-1.5-pro:generateContent"
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d '{
  "instances": [
    {
      "contents": [
        {
          "parts": [
            {
              "text": "happy days",
              "author": "user"  # This could be the expected format
            }
          ]
        }
      ]
    }
  ],
  "parameters": {
    "temperature": 0.9,
    "topP": 1,
    "topK": 1,
    "maxOutputTokens": 2048
  }
}' "https://us-central1-aiplatform.googleapis.com/v1/projects/heroic-oven-430715-i1/locations/us-central1/publishers/google/models/gemini-1.5-pro:generateContent"
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d '{
  "contents": [
    {
      "parts": [
        {
          "text": "happy days",
          "author": "user"  # This line might still be problematic depending on the exact expected field
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.9,
    "topP": 1,
    "topK": 1,
    "maxOutputTokens": 2048
  }
}' "https://us-central1-aiplatform.googleapis.com/v1/projects/heroic-oven-430715-i1/locations/us-central1/publishers/google/models/gemini-1.5-pro:generateContent"
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d '{
  "contents": [
    {
      "parts": [
        {
          "text": "happy days"  # Correct field
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.9,
    "topP": 1,
    "topK": 1,
    "maxOutputTokens": 2048
  }
}' "https://us-central1-aiplatform.googleapis.com/v1/projects/heroic-oven-430715-i1/locations/us-central1/publishers/google/models/gemini-1.5-pro:generateContent"
curl -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" -d '{
  "contents": [
    {
      "parts": [
        {
          "text": "happy days"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.9,
    "topP": 1,
    "topK": 1,
    "maxOutputTokens": 2048
  }
}' "https://us-central1-aiplatform.googleapis.com/v1/projects/heroic-oven-430715-i1/locations/us-central1/publishers/google/models/gemini-1.5-pro:generateContent"
./scripts/cleanup-all-except-clusters.sh && ./scripts/run.sh
cd container_land
cd swsystem
git fetch origin 7cba62e19a853f5f845e59166aebd6f2f638e456
git checkout 7cba62e19a853f5f845e59166aebd6f2f638e456 -- .
ls
tar --overwrite -xzf /path/to/swsystem_updated.tar.gz -C .
tar --overwrite -xzf ../swsystem_updated.tar.gz -C .
ls
tar --overwrite -xzf ./system_updatet.tar.gz -C .
tar --overwrite -xzf swsystem_updated.tar.gz -C .
./scripts/run.sh 
ls
cd container_land/
cd swsystem
ls
./scripts/cleanup-all-except-clusters.sh 
ls
tar --overwrite -xzf ../swsystem_updated.tar.gz -C .
ls
cd ..
tar --overwrite -xzf ../swsystem_updated.tar.gz -C .
ls
mkdir -p swsystem
tar --overwrite -xzf swsystem_updated.tar.gz -C swsystem
cd swsystem
ls
cd ..
ls
tar --overwrite --strip-components=1 -xzf swsystem_updated.tar.gz -C swsystem
cd swsystem
ls
cd ..
ls
tar --overwrite --strip-components=1 -xzf swsystem_updated_corrected.tar.gz -C swsystem
mkdir -p swsystem
tar --overwrite --strip-components=1 -xzf swsystem_updated_corrected.tar.gz -C swsystem
ls
tar --overwrite --strip-components=1 -xzf swsystem_updated_corrected.tar.gz -C swsystem
cd swsystem
ls
./scripts/run.sh 
curl 34.171.134.23
kubectl logs -n app1-namespace <pod-name>
kubectl describe service -n app1-namespace app1
kubectl describe ingress -n app1-namespace
kubectl get pods -n app1-namespace
kubectl describe pod -n app1-namespace app1-7df4c8c9fb-cdqrz
kubectl describe nodes
kubectl get pods -n app1-namespace
kubectl logs app1-68c67f7895-htqzk -n app1-namespace
kubectl describe pod app1-68c67f7895-htqzk -n app1-namespace
kubectl describe nodes
kubectl get service app1 -n app1-namespace
kubectl describe service app1 -n app1-namespace
kubectl get endpoints app1 -n app1-namespace
kubectl get pods -n app1-namespace --show-labels
kubectl logs app1-68c67f7895-htqzk -n app1-namespace
./scripts/run.sh 
./scripts/cleanup-all-except-clusters.sh 
kubectl describe service app1 -n app1-namespace
kubectl get endpoints app1 -n app1-namespace
kubectl get pods -n app1-namespace --show-labels
kubectl describe pod app1-68c67f7895-zdrd5 -n app1-namespace
cd container_land/
cd flask_app_testing/
chmod +x flask_test_script.sh 
./flask_test_script.sh 
docker build -t flask-app .
docker run -p 80:80 flask-app
./flask_test_script.sh 
docker ps
docker ps -a
docker logs 8d0ce4bd64a1
./flask_test_script.sh 
docker logs 8d0ce4bd64a1
pip install vertexai.generative_models
pip install google-cloud-aiplatform
./flask_test_script.sh 
docker ps
./flask_test_script.sh 
docker ps
./flask_test_script.sh 
docker ps
docker stop 5db0350a0407
docker rm 5db0350a0407
docker run -d -p 8080:8080 flask-app
./flask_test_script.sh 
docker ps
docker stop 1d322f84641d
docker rm 1d322f84641d
docker build -t flask-app flask_app
docker run -d -p 8080:8080 flask-app
docker ps
./flask_test_script.sh 
docker ps
./flask_test_script.sh 
docker ps
docker images
docker rmi $(docker images -f "dangling=true" -q)
docker rm 8d0ce4bd64a1 85ad10fd08b3
docker rmi $(docker images -f "dangling=true" -q)
docker images
docker rm 75055f2e02d8
docker rmi $(docker images -f "dangling=true" -q)
docker images
docker run -d -p 8080:8080 flask-app
docker ps
./flask_test_script.sh 
docker ps
docker images
docker run -d -p 8080:8080 flask-app
docker ps
docker logs 0038d8dce205
ls
./flask_test_script.sh 
gcloud ai models list --region=us-central1 --project=heroic-oven-430715-i1
gcloud ai models list --project=heroic-oven-430715-i1 --filter="display_name=gemini-1.5-pro"
gcloud ai models list --region=us-central1 --project=heroic-oven-430715-i1
ls
cd ..
ls
mkdir swsystem
ls
cd swsystem
git fetch origin 7cba62e19a853f5f845e59166aebd6f2f638e456
ls
cd ..
git fetch origin 7cba62e19a853f5f845e59166aebd6f2f638e456
cd swsystem
ls
git fetch origin 7cba62e19a853f5f845e59166aebd6f2f638e456
git checkout 7cba62e19a853f5f845e59166aebd6f2f638e456 -- .
ls
cd ..
ls
untar swsytem.tar.gz
tar -xzf swsystem.tar.gz
ls
cd swsystem
ls
cd container_land/
cd swsystem
./scripts/run.sh 
kubectl get svc -n app1-namespace
kubectl get pods -n app1-namespace -o wide
kubectl logs app1-5778d57555-t9zcx -n app1-namespace
# Build the Docker image
docker build -t gcr.io/heroic-oven-430715-i1/app1:latest .
# Push the image to Google Container Registry
docker push gcr.io/heroic-oven-430715-i1/app1:latest
kubectl get svc -n app1-namespace
kubectl get pods -n app1-namespace -o wide
kubectl logs app1-5778d57555-t9zcx -n app1-namespace
./scripts/run.sh 
./scripts/run.sh 
kubectl get pods -n app1-namespace -o wide
kubectl logs app1-5778d57555-t9zcx -n app1-namespace
./scripts/run.sh 
kubectl get pods -n app1-namespace -o wide
kubectl logs app1-5778d57555-t9zcx -n app1-namespace
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
kubectl describe pod app1-5778d57555-9tcdz -n app1-namespace
kubectl logs app1-5778d57555-9tcdz -n app1-namespace
ls
cd co
ls
kubectl get pods -n app1-namespace -o wide
kubectl describe pod app1-5778d57555-2ph6x -n app1-namespace
kubectl logs app1-5778d57555-2ph6x -n app1-namespace
./scripts/run.sh 
kubectl get secret gemini-api-key -n app1-namespace
kubectl create secret generic gemini-api-key --from-literal=api-key=oTmt7n1H9_cWNrWRfuAFbCtQyo -n app1-namespace
kubectl describe secret gemini-api-key -n app1-namespace
kubectl get pods -n app1-namespace -o wide
curl http://34.68.131.161/generate
kubectl get svc -n app1-namespace
kubectl describe svc app1 -n app1-namespace
kubectl get pods -n app1-namespace
kubectl logs <pod-name> -n app1-namespace
kubectl get pods -n ingress-nginx
./scripts/cleanup-all-except-clusters.sh 
kubectl describe pod app1-5cfc6fcdfc-bffr8 -n app1-namespace
./scripts/run.sh 
kubectl get pods -n app1-namespace -o wide
kubectl get svc -n app1-namespace
curl http://34.68.131.161/generate
kubectl logs <pod-name> -n app1-namespace
kubectl get pods -n app1-namespace -o wide
kubectl logs app1-5cfc6fcdfc-bffr8 -n app1-namespace
curl http://34.68.131.161/generate
kubectl describe svc app1 -n app1-namespace
kubectl exec -it app1-5cfc6fcdfc-bffr8 -n app1-namespace -- netstat -tuln
kubectl exec -it app1-5cfc6fcdfc-bffr8 -n app1-namespace -- ss -tuln
kubectl exec -it app1-5cfc6fcdfc-bffr8 -n app1-namespace -- lsof -i -P -n
kubectl exec -it app1-5cfc6fcdfc-bffr8 -n app1-namespace -- sh
./scripts/
cd ..
ls
cd swsystem
gcloud compute firewall-rules list
./scripts/cleanup-all-except-clusters.sh 
./scripts/run.sh 
kubectl get pods -n app1-namespace -o wide
kubectl describe svc app1 -n app1-namespace
kubectl get pods -n app1-namespace -o wide
kubectl describe svc app1 -n app1-namespace
ls
./scripts/cleanup-all-except-clusters.sh && ./scripts/run.sh
ls
