#!/bin/bash

# Set environment variables
export PROJECT_ID="heroic-oven-430715-i1"
export CLUSTER_NAME="python-k8s-demo-cluster-v2"
export ZONE="us-central1-a"
export REGION="us-central1"
export EMAIL="james@swipeleft.ai"
export LOCATION="us-central1"  # Ensure this is the supported region
export MODEL_NAME="gemini-1.5-pro"
export MODEL_VERSION="001"
export MODEL_ID="${MODEL_NAME}-${MODEL_VERSION}"
export MODEL_RESOURCE_PATH="projects/${PROJECT_ID}/locations/${LOCATION}/publishers/google/models/${MODEL_ID}"

# Verify that environment variables are set correctly
if [ -z "$PROJECT_ID" ] || [ -z "$LOCATION" ] || [ -z "$MODEL_RESOURCE_PATH" ]; then
  echo "One or more environment variables are not set correctly."
  exit 1
else
  echo "Environment variables set correctly."
fi

# Step 1: Set up the project directory structure
PROJECT_DIR="flask_app"
TEMPLATE_DIR="$PROJECT_DIR/flask_templates"

# Create directories if they don't exist
mkdir -p $TEMPLATE_DIR

# Step 2: Stop and remove any existing Flask app containers
echo "Stopping and removing any existing Flask app containers..."
EXISTING_CONTAINERS=$(docker ps -aq --filter "ancestor=flask-app")
if [ -n "$EXISTING_CONTAINERS" ]; then
    docker stop $EXISTING_CONTAINERS
    docker rm $EXISTING_CONTAINERS
    echo "Stopped and removed existing containers."
else
    echo "No existing Flask app containers found."
fi

# Step 3: Create app.py with the correct configurations
cat << 'EOF' > $PROJECT_DIR/app.py
import os
import logging
from flask import Flask, request, jsonify, render_template, redirect, url_for
from google.cloud import aiplatform

# Initialize Flask app with the correct template folder relative to the working directory
app = Flask(__name__, template_folder='flask_templates')

# Load environment variables
PROJECT_ID = os.getenv("PROJECT_ID")
LOCATION = os.getenv("LOCATION")
MODEL_RESOURCE_PATH = os.getenv("MODEL_RESOURCE_PATH")

# Set up logging
logging.basicConfig(level=logging.DEBUG)

# Debug: Log environment variables to verify correct settings
logging.debug(f"PROJECT_ID: {PROJECT_ID}, LOCATION: {LOCATION}, MODEL_RESOURCE_PATH: {MODEL_RESOURCE_PATH}")

# Ensure environment variables are correctly set
if not all([PROJECT_ID, LOCATION, MODEL_RESOURCE_PATH]):
    logging.error("One or more environment variables are not set correctly.")
    exit(1)

# Initialize Vertex AI with a supported region and log the initialization process
try:
    logging.debug("Initializing Vertex AI with the following configuration:")
    logging.debug(f"Project: {PROJECT_ID}, Location: {LOCATION}")
    aiplatform.init(project=PROJECT_ID, location=LOCATION)
    logging.info(f"Vertex AI initialized with region: {LOCATION}")
except Exception as e:
    logging.error(f"Failed to initialize Vertex AI with the specified location {LOCATION}: {e}")
    exit(1)

# Function to interact with the Gemini model
def generate_content_with_model(model_resource_path, user_input):
    try:
        # Load the model using its full resource name
        logging.debug(f"Using model resource path: {model_resource_path}")
        model = aiplatform.Model(model_name=model_resource_path)
        payload = {"instances": [{"content": user_input}]}

        # Make a prediction request
        response = model.predict(payload)

        # Check response validity
        if not response or not hasattr(response, 'predictions'):
            logging.error("Invalid response from the model.")
            return "Invalid response from the model."

        logging.debug(f"Generated content: {response.predictions}")
        return response.predictions
    except Exception as e:
        logging.error(f"Error generating content: {e}")
        return str(e)

# Flask route to display the main interface
@app.route('/', methods=['GET', 'POST'])
def home():
    try:
        if request.method == 'POST':
            user_input = request.form.get('user_input', '')
            action = request.form.get('action', '')
            if not user_input:
                logging.error("User input is missing.")
                return jsonify({"error": "User input is required."}), 400
            return redirect(url_for('process_request', user_input=user_input, action=action))

        return render_template('index.html', models={"gemini-1.5-pro": "Gemini 1.5 Pro"})
    except Exception as e:
        logging.error(f"Error in home route: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

# Flask route to process requests and interact with the model
@app.route('/process_request')
def process_request():
    user_input = request.args.get('user_input')
    action = request.args.get('action')

    if not user_input:
        logging.error("User input is missing.")
        return jsonify({"error": "User input is required."}), 400

    try:
        generated_content = generate_content_with_model(MODEL_RESOURCE_PATH, user_input)
        return render_template('result.html', generated_content=generated_content)

    except Exception as e:
        logging.error(f"Error in process_request route: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080, debug=True)  # Ensure Flask runs on port 8080
EOF

# Step 4: Create requirements.txt without version numbers
cat << EOF > $PROJECT_DIR/requirements.txt
Flask
google-cloud-aiplatform
EOF

# Step 5: Create Dockerfile for the Flask app
cat << 'EOF' > $PROJECT_DIR/Dockerfile
# Use the official Python image from the Docker Hub
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port 8080
EXPOSE 8080

# Run the Flask app
CMD ["python", "app.py"]
EOF

# Step 6: Create basic HTML templates
cat << EOF > $TEMPLATE_DIR/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Flask App</title>
</head>
<body>
    <h1>Welcome to the Flask App</h1>
    <form method="POST">
        <label for="model">Model:</label>
        <select name="model">
            <option value="gemini-1.5-pro">Gemini 1.5 Pro</option>
        </select><br>
        <label for="user_input">Input Text:</label>
        <textarea name="user_input"></textarea><br>
        <label for="action">Action:</label>
        <select name="action">
            <option value="summarize">Summarize</option>
            <option value="summarize_and_generate_image">Summarize and Generate Image</option>
        </select><br>
        <button type="submit">Submit</button>
    </form>
</body>
</html>
EOF

cat << EOF > $TEMPLATE_DIR/result.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Result</title>
</head>
<body>
    <h1>Generated Content</h1>
    <p>{{ generated_content }}</p>
</body>
</html>
EOF

# Step 7: Build the Docker image
echo "Building Docker image..."
docker build -t flask-app $PROJECT_DIR

# Step 8: Run the Docker container on port 8080 with environment variables
echo "Running Docker container on port 8080..."
docker run -d -p 8080:8080 \
--env PROJECT_ID="heroic-oven-430715-i1" \
--env CLUSTER_NAME="python-k8s-demo-cluster-v2" \
--env ZONE="us-central1-a" \
--env REGION="us-central1" \
--env EMAIL="james@swipeleft.ai" \
--env LOCATION="us-central1" \
--env MODEL_NAME="gemini-1.5-pro" \
--env MODEL_VERSION="001" \
--env MODEL_ID="${MODEL_NAME}-${MODEL_VERSION}" \
--env MODEL_RESOURCE_PATH="projects/${PROJECT_ID}/locations/${LOCATION}/publishers/google/models/${MODEL_ID}" \
flask-app

echo "Flask app is now running on port 8080. Use Web Preview in Cloud Shell and select 'Preview on port 8080' to access your app."
