#!/bin/bash

# User data script to set up OpenRemote on Ubuntu 22.04
# This script installs Docker, Docker Compose, and runs OpenRemote

set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "OpenRemote EC2 Setup Script"
echo "=========================================="
echo "Started at: $(date)"

# Update system
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install dependencies
echo "Installing dependencies..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    unzip \
    jq

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose (latest version)
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
curl -L "https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify installations
docker --version
docker-compose --version

# Create OpenRemote directory
echo "Setting up OpenRemote..."
mkdir -p /opt/openremote
cd /opt/openremote

# Mount EFS for map data if available (check if EFS is configured)
EFS_DNS_NAME="${efs_dns_name}"
if [ -n "$EFS_DNS_NAME" ] && [ "$EFS_DNS_NAME" != "EFS not enabled" ]; then
    echo "Mounting EFS for map data..."
    apt-get install -y nfs-common
    mkdir -p /opt/openremote/mapdata
    echo "$EFS_DNS_NAME:/ /opt/openremote/mapdata nfs4 defaults,_netdev 0 0" >> /etc/fstab
    mount -a
    echo "EFS mounted at /opt/openremote/mapdata"
fi

# Create docker-compose.yml for OpenRemote
cat > docker-compose.yml << 'EOF'
version: '3.7'

volumes:
  proxy-data:
  postgresql-data:
  manager-data:

services:
  # HAProxy Proxy - Required for routing /auth to Keycloak and /manager to Manager
  proxy:
    image: openremote/proxy:latest
    restart: always
    depends_on:
      manager:
        condition: service_healthy
    ports:
      - "80:80"
      - "443:443"
      - "8883:8883"
    volumes:
      - proxy-data:/deployment
    environment:
      DOMAINNAME: ${hostname}
      LE_EMAIL: ""
    networks:
      - openremote

  postgresql:
    image: openremote/postgresql:latest
    restart: always
    volumes:
      - postgresql-data:/var/lib/postgresql/data
      - manager-data:/storage
    networks:
      - openremote

  keycloak:
    image: openremote/keycloak:latest
    restart: always
    depends_on:
      postgresql:
        condition: service_healthy
    environment:
      KEYCLOAK_ADMIN_PASSWORD: secret
      KC_HOSTNAME: ${hostname}
      KC_HOSTNAME_PORT: -1
    networks:
      - openremote

  manager:
    image: openremote/manager:latest
    restart: always
    depends_on:
      keycloak:
        condition: service_healthy
    ports:
      - "1883:1883"
    environment:
      OR_SETUP_TYPE: ""
      OR_ADMIN_PASSWORD: secret
      OR_HOSTNAME: ${hostname}
      OR_SSL_PORT: -1
      OR_DEV_MODE: false
    volumes:
      - manager-data:/storage
    networks:
      - openremote

networks:
  openremote:
    driver: bridge
EOF

# Set proper permissions
chown -R ubuntu:ubuntu /opt/openremote

# Start OpenRemote
echo "Starting OpenRemote..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start (this may take a few minutes)..."
sleep 30

# Show status
echo "=========================================="
echo "Docker containers status:"
docker-compose ps

# Create a systemd service to auto-start OpenRemote on reboot
cat > /etc/systemd/system/openremote.service << EOF
[Unit]
Description=OpenRemote
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/openremote
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl daemon-reload
systemctl enable openremote.service

# Get instance metadata
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "=========================================="
echo "OpenRemote Installation Complete!"
echo "=========================================="
echo "Completed at: $(date)"
echo ""
echo "Access OpenRemote at:"
echo "  http://$INSTANCE_IP"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: secret"
echo ""
echo "To view logs:"
echo "  cd /opt/openremote"
echo "  docker-compose logs -f"
echo ""
echo "To restart OpenRemote:"
echo "  sudo systemctl restart openremote"
echo ""

# Create backup script if S3 is enabled
S3_BUCKET="${s3_bucket_name}"
if [ -n "$S3_BUCKET" ] && [ "$S3_BUCKET" != "S3 backups not enabled" ]; then
    echo "Setting up automated backups to S3..."
    
    # Create backup script
    cat > /opt/openremote/backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
set -e
BACKUP_DIR="/opt/openremote/backups"
DATE=$(date +%Y-%m-%d-%H%M%S)
mkdir -p $BACKUP_DIR

# Backup database
cd /opt/openremote
docker-compose exec -T postgresql pg_dump -U postgres openremote | gzip > $BACKUP_DIR/postgresql-$DATE.sql.gz

# Upload to S3
aws s3 cp $BACKUP_DIR/postgresql-$DATE.sql.gz s3://${s3_bucket_name}/backups/

# Clean up old local backups (keep last 7 days)
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $DATE"
BACKUP_SCRIPT

    chmod +x /opt/openremote/backup.sh
    
    # Set up daily backup cron job (2 AM daily)
    echo "0 2 * * * ubuntu /opt/openremote/backup.sh >> /var/log/openremote-backup.log 2>&1" > /etc/cron.d/openremote-backup
    chmod 644 /etc/cron.d/openremote-backup
    
    echo "✓ Daily backups configured to S3 bucket: $S3_BUCKET"
    echo "  Backup script: /opt/openremote/backup.sh"
    echo "  Schedule: Daily at 2 AM"
fi

echo "=========================================="

# Create a message of the day
cat > /etc/motd << MOTD

╔══════════════════════════════════════════════════════════╗
║                    OpenRemote Server                     ║
╚══════════════════════════════════════════════════════════╝

OpenRemote is running in Docker at /opt/openremote

Access: http://$INSTANCE_IP
Login:  admin / secret

Useful commands:
  cd /opt/openremote
  docker-compose ps          # View container status
  docker-compose logs -f     # View logs
  docker-compose restart     # Restart services
  sudo systemctl status openremote

MOTD

