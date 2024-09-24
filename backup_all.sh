#!/bin/bash

# Set the GitHub repository URL
GITHUB_REPO="https://github.com/jrbockrath/google_console_sept_23.git"

# Set the local directory to back up
LOCAL_DIR="."

# Create a temporary directory for the backup
BACKUP_DIR=$(mktemp -d)

# Copy all directories to the backup directory
cp -r "$LOCAL_DIR"/* "$BACKUP_DIR"

# Initialize a new Git repository in the backup directory
cd "$BACKUP_DIR"
git init
git add .
git commit -m "Backup of $(date)"

# Push the backup to the GitHub repository
git remote add origin "$GITHUB_REPO"
git push -u origin master

# Clean up the temporary backup directory
rm -rf "$BACKUP_DIR"

echo "Backup complete!"