import os
import httpx
import google.auth
from google.auth.transport.requests import Request
from flask import Flask, request, jsonify

app = Flask(__name__)

PROJECT_ID = "heroic-oven-430715-i1"
LOCATION = "us-central1"
MODEL_NAME = "gemini-1.5-pro"
MODEL_VERSION = "001"

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
