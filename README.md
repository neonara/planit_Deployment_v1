## PlanIt Application - Ubuntu VPS Deployment Guide

A comprehensive task management and planning application built with Django (Backend), Next.js (Frontend), PostgreSQL, Redis, and Nginx. This guide is specifically designed for deployment on Ubuntu VPS servers.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Environment Configuration](#environment-configuration)
- [Deployment Steps](#deployment-steps)
- [Service Configuration](#service-configuration)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Backup & Recovery](#backup--recovery)

## 🏗️ Overview

PlanIt is a full-stack application that provides task management and planning capabilities. The application is containerized using Docker and can be deployed with a single command.

### Tech Stack

- **Backend**: Django REST Framework
- **Frontend**: Next.js (React)
- **Database**: PostgreSQL 15
- **Cache/Queue**: Redis 7
- **Task Queue**: Celery
- **Reverse Proxy**: Nginx
- **Containerization**: Docker & Docker Compose

## 🏛️ Architecture

```
┌─────────────────┐    ┌─────────────────┐
│     Nginx       │    │    Frontend     │
│   (Port 8081)   │───▶│   (Port 3100)   │
│                 │    │   Next.js App   │
└─────────────────┘    └─────────────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│     Backend     │    │     Redis       │
│   (Port 8080)   │───▶│   (Port 6380)   │
│  Django + API   │    │  Cache & Queue  │
└─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │  Celery Worker  │
│   (Port 5433)   │    │   & Beat Sched  │
│    Database     │    │   Background    │
└─────────────────┘    └─────────────────┘
```

## 🔧 Prerequisites

### Ubuntu VPS Requirements

- **OS**: Ubuntu 20.04 LTS or Ubuntu 22.04 LTS (recommended)
- **VPS Specifications**:
  - **RAM**: Minimum 2GB (4GB recommended for production)
  - **CPU**: 2 vCPUs minimum
  - **Storage**: Minimum 20GB SSD storage
  - **Network**: Stable internet connection with sufficient bandwidth
- **Access**: SSH access with sudo privileges
- **Domain**: Optional - A domain name pointing to your VPS IP (for production)

### Required Software (Ubuntu VPS)

- **Docker**: Version 20.0+
- **Docker Compose**: Version 2.0+
- **Git**: For cloning the repository
- **UFW**: For firewall management
- **Nginx**: Reverse proxy (handled by Docker)
- **Certbot**: For SSL certificates (optional)

### VPS Initial Setup

**Step 1: Connect to your VPS**

```bash
# Connect via SSH
ssh root@your-vps-ip-address
# OR if you have a non-root user
ssh your-username@your-vps-ip-address
```

**Step 2: Update Ubuntu system**

```bash
# Update package lists
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git nano htop unzip software-properties-common
```

**Step 3: Install Docker and Docker Compose**

```bash
# Remove old Docker versions
sudo apt remove -y docker docker-engine docker.io containerd runc

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists
sudo apt update

# Install Docker Engine
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Install Docker Compose (standalone)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

**Step 4: Configure UFW Firewall**

```bash
# Enable UFW
sudo ufw enable

# Allow SSH (important - don't lock yourself out!)
sudo ufw allow ssh
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow application ports
sudo ufw allow 8081/tcp  # Main application port
sudo ufw allow 8080/tcp  # Backend API (optional, for direct access)
sudo ufw allow 3100/tcp  # Frontend (optional, for direct access)

# Check firewall status
sudo ufw status verbose
```

**Step 5: Verify Installation**

```bash
# Check Docker version
docker --version
docker-compose --version

# Test Docker (should work without sudo)
# If this fails, log out and log back in
docker run hello-world

# Check system resources
htop
df -h
free -h
docker info
```

## 🚀 Quick Start (Ubuntu VPS)

### 1. Clone and Setup on VPS

```bash
# Navigate to a suitable directory (e.g., /opt or /home/username)
cd /opt  # or cd /home/$USER

# Clone the repository
git clone <your-repository-url>
cd planit

# Make startup script executable
chmod +x start-services.sh

# Create necessary directories with proper permissions
sudo mkdir -p /opt/planit/data/{postgres,redis,media,static}
sudo chown -R $USER:$USER /opt/planit
```

### 2. Configure Environment for VPS

```bash
# Create environment file from example
cp .env.example .env

# Edit environment file with nano
nano .env

# Update with your VPS IP and domain information
# Make sure to change localhost to your VPS IP or domain
```

### 3. Deploy Application on VPS

```bash
# Start all services (interactive mode)
./start-services.sh

# Or with force cleanup for fresh deployment
./start-services.sh --force-cleanup

# Check if all services are running
docker-compose ps
```

### 4. Access Application via VPS

Replace `YOUR_VPS_IP` with your actual VPS IP address or domain:

- **Main Application**: http://YOUR_VPS_IP:8081
- **Frontend Direct**: http://YOUR_VPS_IP:3100
- **Backend API**: http://YOUR_VPS_IP:8080
- **Admin Panel**: http://YOUR_VPS_IP:8080/admin
- **API Documentation**: http://YOUR_VPS_IP:8080/api/docs

### 5. VPS-Specific Post-Deployment Steps

```bash
# Check service status
sudo systemctl status docker
docker-compose ps

# Monitor resource usage
htop
df -h

# Check application logs
docker-compose logs -f

# Test external connectivity
curl http://YOUR_VPS_IP:8081
```

## ⚙️ Environment Configuration (Ubuntu VPS)

### Example Environment File (.env.example)

Create a `.env.example` file in your project root with the following content:

```bash
# Example environment variables for Planit

# General settings
DEBUG=False
DJANGO_SECRET_KEY=your-secret-key
ALLOWED_HOSTS=localhost,127.0.0.1

# Database settings
DB_HOST=your-database-host
DB_PORT=5432
DB_NAME=your-database-name
DB_USER=your-database-user
DB_PASSWORD=your-database-password

POSTGRES_DB=your-database-name
POSTGRES_USER=your-database-user
POSTGRES_PASSWORD=your-database-password

# Email settings
EMAIL_HOST=your-email-host
EMAIL_PORT=587
EMAIL_HOST_USER=your-email@example.com
EMAIL_HOST_PASSWORD=your-email-password

# Redis settings
REDIS_URL=redis://your-redis-host:6379/0

# Celery settings
CELERY_BROKER_URL=redis://your-redis-host:6379/0
CELERY_RESULT_BACKEND=redis://your-redis-host:6379/0

# Frontend .env settings
NEXT_PUBLIC_API_URL=http://your-vps-ip:port/api
NEXT_PUBLIC_WS_URL=ws://your-vps-ip:port
NODE_ENV=production
NEXT_PUBLIC_APP_NAME=AppName
NEXT_PUBLIC_APP_URL=http://your-vps-ip
```

### VPS-Specific Environment Variables

For your actual `.env` file, update the example values with your VPS-specific settings:

```bash
# Production Mode (always False for production VPS)
DEBUG=False

# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_NAME=planit_db
DB_USER=postgres
DB_PASSWORD=your_very_secure_vps_password_here

# PostgreSQL Container Configuration
POSTGRES_DB=planit_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_very_secure_vps_password_here

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_URL=redis://redis:6379/0

# Django Configuration for VPS
DJANGO_SECRET_KEY=your_50_character_random_secret_key_for_production
ALLOWED_HOSTS=YOUR_VPS_IP,your-domain.com,localhost,127.0.0.1,backend,frontend,nginx

# Email Configuration (for notifications and user registration)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your_email@gmail.com
EMAIL_HOST_PASSWORD=your_gmail_app_password

# Production Security Headers
SECURE_SSL_REDIRECT=False  # Set to True if using HTTPS
SECURE_HSTS_SECONDS=0      # Set to 31536000 if using HTTPS
SECURE_BROWSER_XSS_FILTER=True
SECURE_CONTENT_TYPE_NOSNIFF=True

# Celery Configuration
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Frontend Configuration
NEXT_PUBLIC_API_URL=http://YOUR_VPS_IP:8080/api
NEXT_PUBLIC_WS_URL=ws://YOUR_VPS_IP:8080
NODE_ENV=production
NEXT_PUBLIC_APP_NAME=PlanIt
NEXT_PUBLIC_APP_URL=http://YOUR_VPS_IP:8081
```

### VPS-Specific Configuration Steps

**Step 1: Generate Secure Passwords**

```bash
# Generate secure Django secret key
python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

# Generate secure database password
openssl rand -base64 32
```

**Step 2: Update ALLOWED_HOSTS**

```bash
# Replace YOUR_VPS_IP with your actual VPS IP
# Replace your-domain.com with your actual domain (if any)
nano .env

# Example ALLOWED_HOSTS line:
# ALLOWED_HOSTS=45.76.123.45,planit.yourdomain.com,localhost,127.0.0.1,backend,frontend,nginx
```

**Step 3: Configure Email (Optional but Recommended)**

```bash
# For Gmail, generate an App Password:
# 1. Go to Google Account settings
# 2. Enable 2-Factor Authentication
# 3. Generate App Password for "Mail"
# 4. Use the generated password (not your regular Gmail password)
```

### Security Notes for VPS Production

- **🔐 Never use default passwords in production**
- **🔑 Generate strong, unique passwords (32+ characters)**
- **🎯 Always set DEBUG=False for production**
- **🌐 Update ALLOWED_HOSTS with your VPS IP and domain**
- **📧 Use App Passwords for email services**
- **🔒 Consider using environment variables for sensitive data**
- **📝 Keep a secure backup of your .env file**

## 📦 Deployment Steps

### Step 1: Prepare Environment

```bash
# Ensure you're in the project directory
cd /path/to/planit

# Set correct permissions
chmod +x start-services.sh

# Create .env file from example template
cp .env.example .env
nano .env  # Edit with your specific settings
```

### Step 2: Configure Services

```bash
# Review and update environment variables
nano .env

# Ensure Docker is running
docker info
```

### Step 3: Deploy Services

```bash
# Option 1: Interactive deployment (recommended)
./start-services.sh

# Option 2: Automated deployment
./start-services.sh --force-cleanup

# Option 3: Manual deployment
docker-compose up -d
```

### Step 4: Verify Deployment

```bash
# Check service status
docker-compose ps

# Check service logs
docker-compose logs -f

# Test service endpoints
curl http://localhost:8081/health
curl http://localhost:8080/api/health
```

## 🔧 Service Configuration

### Port Mappings

| Service    | Internal Port | External Port | Description           |
| ---------- | ------------- | ------------- | --------------------- |
| Nginx      | 80/443        | 8081/8443     | Reverse proxy & SSL   |
| Frontend   | 3000          | 3100          | Next.js application   |
| Backend    | 8000          | 8080          | Django REST API       |
| PostgreSQL | 5432          | 5433          | Database              |
| Redis      | 6379          | 6380          | Cache & message queue |

### Volume Mounts

- `postgres_data`: Database persistence
- `redis_data`: Redis persistence
- `media_files`: User uploaded files
- `static_files`: Static assets
- SSL certificates: `./nginx/ssl`

### Health Checks

All services include health checks with automatic restart capabilities:

- **PostgreSQL**: Database connectivity check
- **Redis**: PING command test
- **Backend**: HTTP endpoint check
- **Frontend**: HTTP endpoint check
- **Nginx**: HTTP endpoint check

## 📊 Monitoring & Maintenance

### Checking Service Status

```bash
# View all service status
docker-compose ps

# View specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f nginx

# View system resource usage
docker stats
```

### Common Management Commands

```bash
# Restart a specific service
docker-compose restart backend

# Stop all services
docker-compose down

# Stop and remove all data (CAUTION!)
docker-compose down -v

# Update services (pull latest images)
docker-compose pull
docker-compose up -d

# Access service shell
docker-compose exec backend bash
docker-compose exec postgres psql -U postgres -d planit_db
```

### Database Management

```bash
# Backup database
docker-compose exec postgres pg_dump -U postgres planit_db > backup.sql

# Restore database
docker-compose exec -T postgres psql -U postgres planit_db < backup.sql

# Access database directly
docker-compose exec postgres psql -U postgres -d planit_db
```

## 🔧 Troubleshooting (Ubuntu VPS)

### VPS-Specific Common Issues & Solutions

#### 1. Cannot Connect to VPS Application from Outside

```bash
# Check if services are running
docker-compose ps

# Verify ports are open on VPS
sudo netstat -tlnp | grep -E ':(8080|8081|3100|5433|6380)'

# Check UFW firewall rules
sudo ufw status verbose

# Test connectivity from inside VPS
curl http://localhost:8081

# Check if ports are blocked by cloud provider firewall
# (AWS Security Groups, DigitalOcean Firewall, etc.)
```

#### 2. Services Won't Start on VPS

```bash
# Check Docker daemon status
sudo systemctl status docker

# Check available memory and disk space
free -h
df -h

# Check for port conflicts
sudo netstat -tlnp | grep -E ':(8080|8081|3100|5433|6380)'

# Check Docker logs
docker-compose logs --tail=50

# Force cleanup and restart
./start-services.sh --force-cleanup
```

#### 3. VPS Performance Issues

```bash
# Monitor system resources
htop
iotop -o

# Check Docker resource usage
docker stats

# Monitor disk usage
df -h
du -sh /var/lib/docker/

# Check memory usage by containers
docker-compose exec backend free -h
docker-compose exec postgres free -h

# Optimize if running low on resources
docker system prune -f
docker volume prune -f
```

#### 4. Database Connection Issues on VPS

```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Check if PostgreSQL container is healthy
docker-compose exec postgres pg_isready -U postgres

# Restart database service
docker-compose restart postgres

# Check database connections from backend
docker-compose exec backend python manage.py dbshell

# Monitor PostgreSQL connections
docker-compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

#### 5. Network/DNS Issues on VPS

```bash
# Test DNS resolution
nslookup google.com
dig google.com

# Check Docker network
docker network ls
docker network inspect planit_network

# Test container-to-container communication
docker-compose exec frontend ping backend
docker-compose exec backend ping postgres

# Verify environment variables
docker-compose exec backend env | grep -E '(DB_|REDIS_|ALLOWED_HOSTS)'

# Check if services can reach external APIs
docker-compose exec backend curl -I https://api.github.com
```

#### 6. SSL/HTTPS Issues

```bash
# Check SSL certificate validity
openssl x509 -in nginx/ssl/nginx.crt -text -noout

# Test SSL connection
openssl s_client -connect YOUR_VPS_IP:8443 -servername your-domain.com

# Check nginx SSL configuration
docker-compose exec nginx nginx -t

# Renew Let's Encrypt certificates
sudo certbot renew --dry-run
```

#### 7. File Permission Issues on VPS

```bash
# Fix ownership issues
sudo chown -R $USER:$USER /opt/planit
sudo chown -R $USER:docker /opt/planit/data

# Fix permission issues
chmod +x start-services.sh
chmod 600 .env
chmod -R 755 nginx/

# Check Docker socket permissions
ls -la /var/run/docker.sock
sudo usermod -aG docker $USER
# Log out and back in
```

#### 8. Memory/Resource Exhaustion

```bash
# Check system memory
free -h
cat /proc/meminfo

# Check swap usage
swapon --show

# Add swap if needed (on VPS with <4GB RAM)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Optimize Docker memory usage
docker system prune -a
docker-compose down
docker-compose up -d
```

#### 9. VPS Firewall Issues

```bash
# Check UFW status and rules
sudo ufw status verbose
sudo ufw status numbered

# Reset firewall if needed (CAREFUL!)
sudo ufw --force reset

# Re-add essential rules
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8081/tcp
sudo ufw enable

# Check iptables rules
sudo iptables -L

# Check cloud provider firewall settings
# (AWS Security Groups, DigitalOcean, Vultr, etc.)
```

#### 10. Application-Specific Issues

```bash
# Django backend issues
docker-compose logs backend
docker-compose exec backend python manage.py check
docker-compose exec backend python manage.py collectstatic

# Next.js frontend issues
docker-compose logs frontend
docker-compose exec frontend npm run build

# Nginx reverse proxy issues
docker-compose logs nginx
docker-compose exec nginx nginx -t
docker-compose exec nginx nginx -s reload

# Celery worker issues
docker-compose logs celery_worker
docker-compose exec celery_worker celery -A planit inspect active
```

### VPS Emergency Recovery Commands

```bash
# Complete service restart
docker-compose down && docker-compose up -d

# Emergency stop all containers
docker stop $(docker ps -q)

# Clean slate restart (WARNING: Removes all data)
docker-compose down -v
docker system prune -a
./start-services.sh --force-cleanup

# Check VPS system health
sudo systemctl status
sudo journalctl -u docker --since "1 hour ago"
dmesg | tail -20
```

# Fix Docker permissions

sudo usermod -aG docker $USER

# Then log out and back in

---

_Last updated: July 2, 2025_
_Version: 1.0.1_
