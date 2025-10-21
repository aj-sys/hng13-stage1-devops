#!/bin/bash
LOGFILE="deploy_$(date +%Y%m%d).log"
exec > >(tee -a "$LOGFILE") 2>&1

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
# Optional cleanup flag
if [ "$1" == "--cleanup" ]; then
  echo "🧹 Cleaning up..."
  ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "sudo docker stop \$(sudo docker ps -q) && sudo docker rm \$(sudo docker ps -aq)"
  exit 0
fi


echo "📥 Cloning repository..."
if [ -d "repo" ]; then
  cd repo && git pull origin $BRANCH
else
  git clone https://${PAT}@${REPO_URL#https://} repo
  cd repo
  git checkout $BRANCH
fi

# --- Step 3: Copy project to remote server ---
echo "📤 Copying project to remote server..."
scp -i "$SSH_KEY" -r . "$SSH_USER@$SERVER_IP:/home/$SSH_USER/app"

# --- Step 4: Deploy Dockerized application remotely ---
echo "🐳 Deploying Dockerized application..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
cd /home/$SSH_USER/app

if [ -f docker-compose.yml ]; then
  sudo docker-compose up -d --build
else
  sudo docker build -t myapp .
  sudo docker run -d -p $APP_PORT:$APP_PORT myapp
fi
EOF

# --- Step 5: Configure NGINX as reverse proxy ---
echo "🌐 Configuring NGINX..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
sudo bash -c 'cat > /etc/nginx/sites-available/myapp <<EOL
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL'
sudo ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
EOF

# --- Step 6: Validate deployment ---
echo "✅ Validating deployment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
sudo systemctl status docker | grep active
sudo docker ps
curl -I http://localhost
EOF

echo "Deployment complete! Access your app at: http://$SERVER_IP/"
