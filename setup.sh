#!/bin/bash
# setup.sh - Collect environment variables for deployment

# Logging setup
LOGFILE="setup_$(date +%Y%m%d).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "🚀 Starting Setup Script..."

# Collect user input
read -p "Enter Git Repository URL: " REPO_URL
read -p "Enter your Personal Access Token: " PAT
read -p "Enter Branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -p "Enter SSH Username: " SSH_USER
read -p "Enter Server IP Address: " SERVER_IP
read -p "Enter SSH Key Path (e.g., ~/.ssh/id_rsa): " SSH_KEY
read -p "Enter Application Port (container port): " APP_PORT

# Validate required fields
if [ -z "$REPO_URL" ] || [ -z "$SSH_USER" ] || [ -z "$SERVER_IP" ] || [ -z "$SSH_KEY" ]; then
  echo "❌ Missing required fields. Exiting..."
  exit 1
fi

# Optional cleanup
if [ "$1" == "--cleanup" ]; then
  echo "🧹 Cleaning up previous deployment..."
  ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" \
    "sudo docker stop \$(sudo docker ps -q) && sudo docker rm \$(sudo docker ps -aq)"
  exit 0
fi

# Save variables to a temporary file to be sourced by deploy.sh
cat > .env <<EOL
REPO_URL=$REPO_URL
PAT=$PAT
BRANCH=$BRANCH
SSH_USER=$SSH_USER
SERVER_IP=$SERVER_IP
SSH_KEY=$SSH_KEY
APP_PORT=$APP_PORT
EOL

echo "✅ Setup complete! Run deploy.sh to deploy your application."

