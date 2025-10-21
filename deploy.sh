#!/bin/bash
# deploy.sh - Deploy project using collected variables

# Logging setup
LOGFILE="deploy_$(date +%Y%m%d).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "🚀 Starting Deployment Script..."

# Load variables from setup.sh
if [ ! -f .env ]; then
  echo "❌ .env file not found. Run setup.sh first."
  exit 1
fi
source .env

# --- Clone repository locally ---
echo "📥 Cloning repository..."
if [ -d "repo" ]; then
  cd repo && git pull origin $BRANCH
else
  git clone https://${PAT}@${REPO_URL#https://} repo
  cd repo
  git checkout $BRANCH
fi

# --- Copy project to remote server ---
echo "📤 Copying project to remote server..."
scp -i "$SSH_KEY" -r . "$SSH_USER@$SERVER_IP:/home/$SSH_USER/app"

# --- Deploy Dockerized app remotely ---
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

# --- Configure Nginx as reverse proxy ---
echo "🌐 Configuring Nginx..."
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

# --- Validate deployment ---
echo "✅ Validating deployment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" <<EOF
sudo systemctl status docker | grep active
sudo docker ps
curl -I http://localhost
EOF

echo "🎉 Deployment complete! Access your app at http://$SERVER_IP/"

