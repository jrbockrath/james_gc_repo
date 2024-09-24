#!/usr/bin/env python3

import sys
import subprocess
import pkg_resources
import os
from flask import Flask, request, redirect, session, render_template_string
import logging
import json
import secrets
import requests
from datetime import datetime
import httpx
import google.auth
from google.auth.transport.requests import Request

# Install required packages
required_packages = {
    'flask': 'Flask',
    'requests': 'requests',
    'google-auth': 'google-auth',
    'httpx': 'httpx',
}

def install_packages():
    for import_name, pkg_name in required_packages.items():
        try:
            pkg_resources.get_distribution(pkg_name)
        except pkg_resources.DistributionNotFound:
            print(f"{pkg_name} not found, installing...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", pkg_name])
        else:
            print(f"{pkg_name} is already installed.")

print("Checking and installing required packages...")
install_packages()

# Set up logging
logging.basicConfig(level=logging.DEBUG)

# LinkedIn application credentials
CLIENT_ID = '86w3md8ut4viid'
CLIENT_SECRET = 'gwRZXwiDEwUidtnz'
REDIRECT_URI = 'https://8080-cs-163298817664-default.cs-us-central1-pits.cloudshell.dev/callback'

# Set up Google Cloud project details
PROJECT_ID = "heroic-oven-430715-i1"
LOCATION = "us-central1"
MODEL_NAME = "gemini-1.5-pro-001"  # Correct Model ID for Gemini 1.5 Pro

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.urandom(24)  # for session management

def get_credentials():
    credentials, _ = google.auth.default(
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    credentials.refresh(Request())
    return credentials.token

def build_endpoint_url():
    return f"https://{LOCATION}-aiplatform.googleapis.com/v1/projects/{PROJECT_ID}/locations/{LOCATION}/publishers/google/models/{MODEL_NAME}:streamGenerateContent"

def generate_post_content():
    try:
        access_token = get_credentials()
        
        url = build_endpoint_url()

        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        data = {
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {"text": "Generate a short, engaging LinkedIn post about AI and its impact on business."}
                    ]
                }
            ],
            "generation_config": {
                "temperature": 0.2,
                "max_output_tokens": 256,
                "top_p": 0.95,
                "top_k": 40
            }
        }

        logging.debug(f"Sending request to {url}")
        logging.debug(f"Request data: {json.dumps(data, indent=2)}")

        with httpx.Client() as client:
            resp = client.post(url, json=data, headers=headers, timeout=None)
            
        logging.debug(f"Response status code: {resp.status_code}")
        logging.debug(f"Response content: {resp.text}")

        if resp.status_code == 200:
            response_data = resp.json()
            # Parse the response to extract the generated content
            generated_content = ""
            try:
                for chunk in response_data:
                    for candidate in chunk.get('candidates', []):
                        content = candidate.get('content', {})
                        for part in content.get('parts', []):
                            generated_content += part.get('text', '')
            except Exception as e:
                logging.error(f"Error parsing response: {e}")
                logging.error(f"Full response: {response_data}")
                return f"An error occurred while parsing the generated content: {str(e)}"

            if not generated_content:
                logging.error("No content generated from the model")
                return "The AI model did not generate any content."

            logging.debug(f"Generated content: {generated_content}")
            return generated_content.strip()
        else:
            error_message = f"Error calling Gemini 1.5 Pro: {resp.text}"
            logging.error(error_message)
            return error_message

    except Exception as e:
        error_message = f"Error in generate_post_content: {str(e)}"
        logging.error(error_message)
        logging.exception("Exception details:")
        return error_message
        
@app.route('/')
def index():
    return "Server is running. Please use the /login route to start the OAuth process."

@app.route('/login')
def login():
    state = secrets.token_urlsafe(16)
    session['oauth_state'] = state
    auth_url = f"https://www.linkedin.com/oauth/v2/authorization?response_type=code&client_id={CLIENT_ID}&redirect_uri={REDIRECT_URI}&state={state}&scope=openid%20profile%20email%20w_member_social"
    return redirect(auth_url)

@app.route('/callback')
def callback():
    logging.info("Callback route accessed")
    logging.info(f"Full URL: {request.url}")
    logging.info(f"Args: {request.args}")

    if request.args.get('state') != session.get('oauth_state'):
        return "Invalid state parameter. Possible CSRF attack.", 400

    code = request.args.get('code')
    if code:
        token_url = 'https://www.linkedin.com/oauth/v2/accessToken'
        data = {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': REDIRECT_URI,
            'client_id': CLIENT_ID,
            'client_secret': CLIENT_SECRET
        }
        headers = {
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        response = requests.post(token_url, data=data, headers=headers)
        logging.info(f"Token exchange response: {response.text}")
        if response.status_code == 200:
            token_data = response.json()
            access_token = token_data.get('access_token')
            session['access_token'] = access_token

            user_info_url = 'https://api.linkedin.com/v2/userinfo'
            headers = {'Authorization': f'Bearer {access_token}'}
            user_info_response = requests.get(user_info_url, headers=headers)
            logging.info(f"User info response: {user_info_response.text}")
            if user_info_response.status_code == 200:
                user_info = user_info_response.json()
                session['user_info'] = user_info
                return redirect('/post')
            else:
                return f"Error fetching user info: {user_info_response.text}", 400
        else:
            return f"Error exchanging code for token: {response.text}", 400
    return "Error: No code provided", 400

@app.route('/post', methods=['GET', 'POST'])
def post():
    if 'access_token' not in session:
        return redirect('/login')

    if request.method == 'POST':
        # Generate post content using Gemini 1.5 Pro
        text = generate_post_content()

        if text.startswith("An error occurred") or text.startswith("Error"):
            error_message = f"Failed to generate post content: {text}"
            logging.error(error_message)
            return error_message, 400

        logging.debug(f"Content to be posted: {text}")
        print(f"Content to be posted: {text}")
        post_url = 'https://api.linkedin.com/v2/ugcPosts'
        headers = {
            'Authorization': f"Bearer {session['access_token']}",
            'Content-Type': 'application/json',
            'X-Restli-Protocol-Version': '2.0.0'
        }
        post_data = {
            "author": f"urn:li:person:{session['user_info']['sub']}",
            "lifecycleState": "PUBLISHED",
            "specificContent": {
                "com.linkedin.ugc.ShareContent": {
                    "shareCommentary": {
                        "text": text
                    },
                    "shareMediaCategory": "NONE"
                }
            },
            "visibility": {
                "com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"
            }
        }
        response = requests.post(post_url, headers=headers, json=post_data)
        if response.status_code == 201:
            return f"AI-generated post successfully created on LinkedIn: '{text}' <br><a href='/post'>Create another post</a>"
        elif response.status_code == 422 and "DUPLICATE_POST" in response.text:
            logging.warning("Duplicate post detected. Regenerating content...")
            print("Duplicate post detected. Regenerating content...")
            new_text = generate_post_content()
            # Retry posting with new content
        else:
            error_message = f"Error creating post: {response.text}"
            logging.error(error_message)
            return error_message, 400

    # If GET request or post not successful, show a button to generate and post
    return render_template_string('''
        <h2>Generate and Post to LinkedIn</h2>
        <form method="post">
            <input type="submit" value="Generate AI Content and Post to LinkedIn">
        </form>
    ''')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)