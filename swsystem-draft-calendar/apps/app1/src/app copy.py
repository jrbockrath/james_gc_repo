import os
import httpx
import google.auth
from google.auth.transport.requests import Request
from flask import Flask, request, jsonify, render_template, redirect, url_for

# Initialize Flask app with the correct template folder relative to the working directory
app = Flask(__name__, template_folder='flask_templates')

# Configuration for Vertex AI
PROJECT_ID = "heroic-oven-430715-i1"
LOCATION = "us-central1"
MODELS = {
    "gemini-1.5-pro": "Gemini 1.5 Pro",
    "summarization-1.0": "Summarization Model 1.0",
    "image-generation-2.0": "Image Generation Model 2.0"
}
MODEL_VERSION = "001"

# Function to get access token for authentication
def get_credentials():
    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    credentials.refresh(Request())
    return credentials.token

# Function to build endpoint URL for the selected model
def build_endpoint_url(model_name, streaming: bool = False):
    base_url = f"https://{LOCATION}-aiplatform.googleapis.com/v1/"
    project_fragment = f"projects/{PROJECT_ID}"
    location_fragment = f"locations/{LOCATION}"
    specifier = "streamGenerateContent" if streaming else "generateContent"
    model_fragment = f"publishers/google/models/{model_name}"
    url = f"{base_url}{'/'.join([project_fragment, location_fragment, model_fragment])}:{specifier}"
    return url

# Route to display the main interface
@app.route('/', methods=['GET', 'POST'])
def home():
    try:
        if request.method == 'POST':
            model_name = request.form['model']
            user_input = request.form['user_input']
            action = request.form['action']
            return redirect(url_for('process_request', model_name=model_name, user_input=user_input, action=action))
        # Debug logs
        print("Serving index.html from:", app.template_folder)
        return render_template('index.html', models=MODELS)
    except Exception as e:
        # Log the error for debugging purposes
        print(f"Error in home route: {e}")
        return jsonify({"error": str(e)}), 500

# Route to process the request and chain model calls
@app.route('/process', methods=['GET'])
def process_request():
    model_name = request.args.get('model_name')
    user_input = request.args.get('user_input')
    action = request.args.get('action')

    access_token = get_credentials()
    url = build_endpoint_url(model_name, streaming=False)

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
    }

    # Call the selected model with user input
    payload = {
        "contents": [{"parts": [{"text": user_input}]}],
        "generationConfig": {
            "temperature": 0.9,
            "topP": 1,
            "topK": 1,
            "maxOutputTokens": 2048,
        },
    }

    try:
        with httpx.Client() as client:
            resp = client.post(url, json=payload, headers=headers, timeout=None)
            response_data = resp.json()

        if action == "summarize_and_generate_image":
            summary = response_data['candidates'][0]['content']['parts'][0]['text']
            
            # Call the image generation model using the summary
            image_model_name = "image-generation-2.0"
            image_url = build_endpoint_url(image_model_name, streaming=False)
            image_payload = {
                "contents": [{"parts": [{"text": summary}]}],
                "generationConfig": {
                    "temperature": 0.7,
                    "topP": 1,
                    "topK": 1,
                    "maxOutputTokens": 512,
                },
            }
            image_resp = client.post(image_url, json=image_payload, headers=headers, timeout=None)
            image_data = image_resp.json()
            image_result = image_data['candidates'][0]['content']['parts'][0]['text']
            return render_template('result.html', summary=summary, image=image_result)

        generated_content = response_data['candidates'][0]['content']['parts'][0]['text']
        return render_template('result.html', generated_content=generated_content)
    
    except Exception as e:
        # Log the error for debugging purposes
        print(f"Error in process_request route: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    # Log the current working directory and template folder
    print("Current Working Directory:", os.getcwd())
    print("Flask Template Folder:", app.template_folder)
    app.run(host='0.0.0.0', port=80, debug=True)
