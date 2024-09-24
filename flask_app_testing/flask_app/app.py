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
