#!/bin/bash

# Set your GitHub username
GITHUB_USERNAME="your-username"



# Loop through each folder in the projects directory
for folder in */; do
    # Remove trailing slash from folder name
    REPO_NAME=${folder%/}

    # Create a new repository on GitHub
    echo "Creating GitHub repository: $REPO_NAME"
    gh repo create "$GITHUB_USERNAME/$REPO_NAME" --private --confirm

    # Initialize git, add remote, commit, and push the folder to GitHub
    echo "Backing up folder: $REPO_NAME"
    cd "$REPO_NAME" || { echo "Failed to enter directory: $REPO_NAME"; exit 1; }
    git init
    git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
    git add .
    git commit -m "Initial commit"
    git branch -M main
    git push -u origin main
    cd ..

    echo "Backup of $REPO_NAME completed."
done

echo "All folders have been backed up to GitHub."
