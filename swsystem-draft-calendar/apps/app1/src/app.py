import os
import httpx
import google.auth
from google.auth.transport.requests import Request
from flask import Flask, request, jsonify, render_template, redirect, url_for
from google.cloud import secretmanager
from cronofy import Cronofy
from werkzeug.utils import secure_filename

   
client_id = os.environ.get('CRONOFY_CLIENT_ID')
client_secret = os.environ.get('CRONOFY_CLIENT_SECRET')
cronofy_client = Cronofy(client_id=client_id, client_secret=client_secret)

app = Flask(__name__)

PROJECT_ID = "heroic-oven-430715-i1"
LOCATION = "us-central1"
MODELS = {
    "gemini-1.5-pro": "Gemini 1.5 Pro"
}
MODEL_VERSION = "001"
UPLOAD_FOLDER = '/tmp/uploads'
ALLOWED_EXTENSIONS = {'txt', 'pdf', 'doc', 'docx'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def get_credentials():
    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    credentials.refresh(Request())
    return credentials.token

def get_cronofy_credentials():
    client = secretmanager.SecretManagerServiceClient()
    client_id = client.access_secret_version(request={"name": f"projects/{PROJECT_ID}/secrets/cronofy-client-id/versions/latest"}).payload.data.decode("UTF-8")
    client_secret = client.access_secret_version(request={"name": f"projects/{PROJECT_ID}/secrets/cronofy-client-secret/versions/latest"}).payload.data.decode("UTF-8")
    return client_id, client_secret

def build_endpoint_url(model_name, streaming: bool = False):
    base_url = f"https://{LOCATION}-aiplatform.googleapis.com/v1/"
    project_fragment = f"projects/{PROJECT_ID}"
    location_fragment = f"locations/{LOCATION}"
    specifier = "streamGenerateContent" if streaming else "generateContent"
    model_fragment = f"publishers/google/models/{model_name}"
    url = f"{base_url}{'/'.join([project_fragment, location_fragment, model_fragment])}:{specifier}"
    return url

@app.route('/', methods=['GET', 'POST'])
def home():
    if request.method == 'POST':
        if 'file' not in request.files:
            return jsonify({"error": "No file part"}), 400
        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No selected file"}), 400
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)
            return redirect(url_for('process_document', filename=filename))
    return render_template('index.html')

@app.route('/process_document/<filename>', methods=['GET'])
def process_document(filename):
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    with open(filepath, 'r') as file:
        document_text = file.read()

    access_token = get_credentials()
    url = build_endpoint_url("gemini-1.5-pro", streaming=False)

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
    }

    prompt = """
    Analyze the following document and identify all due dates for activities listed in the text. 
    These are critical dates for a realtor to ensure a smooth sale of a property and prevent any contract timing breach. 
    Return a list of dates and corresponding meeting purposes from the document in the following JSON format:
    [
        {
            "date": "YYYY-MM-DD",
            "purpose": "Brief description of the activity or meeting"
        },
        ...
    ]
    """

    payload = {
        "contents": [{"parts": [{"text": prompt + "\n\n" + document_text}]}],
        "generationConfig": {
            "temperature": 0.2,
            "topP": 1,
            "topK": 1,
            "maxOutputTokens": 2048,
        },
    }

    try:
        with httpx.Client() as client:
            resp = client.post(url, json=payload, headers=headers, timeout=None)
            response_data = resp.json()

        generated_content = response_data['candidates'][0]['content']['parts'][0]['text']
        # Assuming the model returns properly formatted JSON
        import json
        events = json.loads(generated_content)
        return render_template('events_confirmation.html', events=events)
    except Exception as e:
        print(f"Error in process_document: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/create_events', methods=['POST'])
def create_events():
    events = request.json.get('events')
    email = request.json.get('email')

    if not events or not email:
        return jsonify({"error": "Missing events or email"}), 400

    client_id, client_secret = get_cronofy_credentials()
    cronofy_client = Cronofy(client_id=client_id, client_secret=client_secret)

    try:
        for event in events:
            cronofy_client.upsert_event(
                calendar_id='primary',
                event_id=f"realestate_{event['date']}_{hash(event['purpose'])}",
                event={
                    'start': f"{event['date']}T09:00:00Z",
                    'end': f"{event['date']}T10:00:00Z",
                    'summary': event['purpose'],
                    'description': "Real estate activity",
                    'attendees': [{'email': email}]
                }
            )
        return jsonify({"message": "Events created successfully"}), 200
    except Exception as e:
        print(f"Error creating events: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    app.run(host='0.0.0.0', port=80, debug=True)