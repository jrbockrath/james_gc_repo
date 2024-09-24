#!/bin/bash

# Set variables
GITHUB_USER="jrbockrath"
REPO_NAME="james_gc_repo"
REMOTE_URL="https://github.com/$GITHUB_USER/$REPO_NAME.git"

# Navigate to the directory containing containerland
cd /home/jamesrbockrath/container_land  # Replace this with your actual path

# Remove any existing .git directory to start fresh (WARNING: This will remove the git history)
rm -rf .git

# Initialize git
git init

# Include hidden files and directories
shopt -s dotglob
shopt -s nullglob

# Add all files and directories, ensuring hidden files are included
git add --all

# Verify files added to git
echo "=== Verifying all files added ==="
git status

# Check specifically for the swsystem directory
echo "=== Checking contents of swsystem directory ==="
find swsystem -type f

# Check if the swsystem directory is being tracked by Git
echo "=== Checking if swsystem directory is tracked by Git ==="
git ls-files swsystem

# Commit the changes
git commit -m "Ensuring all files from containerland, including swsystem, are committed"

# Set the remote URL if not already set
git remote add origin $REMOTE_URL

# Rename branch to main (if needed)
git branch -M main

# Force push changes to the remote repository
git push -u origin main --force
