#!/bin/bash

echo "🚀 Starting Automated Deployment Script..."

read -p "Enter Git Repository URL: " REPO_URL
read -p "Enter your Personal Access Token: " PAT
read -p "Enter Branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -p "Enter SSH Username: " SSH_USER
read -p "Enter Server IP Address: " SERVER_IP
read -p "Enter SSH Key Path (e.g., ~/.ssh/id_rsa): " SSH_KEY
read -p "Enter Application Port (container port): " APP_PORT


if [ -z "$REPO_URL" ] || [ -z "$SSH_USER" ] || [ -z "$SERVER_IP" ]; then
  echo "❌ Missing required fields. Exiting..."
  exit 1
fi


echo "📥 Cloning repository..."
if [ -d "repo" ]; then
  cd repo && git pull origin $BRANCH
else
  git clone https://${PAT}@${REPO_URL#https://} repo
  cd repo
  git checkout $BRANCH
fi
