#!/bin/bash
#
# Nextcloud AIO installation script for cursoteca
# Ubuntu 24.04.3 LTS
#

set -e  # Exit on error

echo "========================================="
echo "Nextcloud AIO Installation"
echo "cursoteca - PoC Configuration"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

# ====== 1. CHECK PERMISSIONS ======
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}This script must be run as root (sudo)${NC}"
   exit 1
fi

# ====== 2. UPDATE SYSTEM ======
echo -e "${YELLOW}[1/8] Updating system packages...${NC}"
apt update
apt upgrade -y

# ====== 3. INSTALL DOCKER ======
echo -e "${YELLOW}[2/8] Installing Docker and Docker Compose...${NC}"

# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
    # Install dependencies
    apt install -y \
        ca-certificates \
        curl
    
    install -m 0755 -d /etc/apt/keyrings
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add the repository to Apt sources:
    tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    
    # Instalar Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Enable Docker on startup
    systemctl enable docker
    systemctl start docker
    
    echo -e "${GREEN}✓ Docker installed successfully${NC}"
else
    echo -e "${GREEN}✓ Docker is already installed${NC}"
fi

# ====== 4. CREATE STORAGE DIRECTORIES ======
echo -e "${YELLOW}[3/8] Creating storage directories...${NC}"

# Directories for Nextcloud data
mkdir -p /mnt/nextcloud_storage
mkdir -p /mnt/nextcloud_backups
mkdir -p /var/lib/nextcloud-aio-config

# Adjust permissions
chmod 750 /mnt/nextcloud_storage
chmod 750 /mnt/nextcloud_backups
chmod 750 /var/lib/nextcloud-aio-config

echo -e "${GREEN}✓ Directories created${NC}"

# ====== 5. GET SCRIPT DIRECTORY ======
echo -e "${YELLOW}[4/8] Getting script configuration...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/opt/nextcloud-aio-cursoteca"
mkdir -p "$PROJECT_DIR"

echo -e "${GREEN}✓ Script directory: $SCRIPT_DIR${NC}"
echo -e "${GREEN}✓ Project directory: $PROJECT_DIR${NC}"

# ====== 6. CHECK .env FILE ======
echo -e "${YELLOW}[5/8] Checking .env configuration file...${NC}"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}✗ Error: Not found $SCRIPT_DIR/.env${NC}"
    echo -e "${RED}Please create a .env file in the same directory as the script${NC}"
    exit 1
fi

# Copy .env to project directory
cp "$SCRIPT_DIR/.env" "$PROJECT_DIR/.env"
echo -e "${GREEN}✓ .env file copied to $PROJECT_DIR${NC}"

# ====== 7. CHECK DOCKER COMPOSE ======
echo -e "${YELLOW}[6/8] Checking docker-compose.yml...${NC}"

if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    echo -e "${RED}✗ Error: Couldn't found $SCRIPT_DIR/docker-compose.yml${NC}"
    echo -e "${RED}Please create a docker-compose.yml file in the same directory as the script${NC}"
    exit 1
fi

# Copy docker-compose.yml to project directory
cp "$SCRIPT_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
echo -e "${GREEN}✓ docker-compose.yml copied to $PROJECT_DIR${NC}"

# ====== 8. START CONTAINERS ======
echo -e "${YELLOW}[7/8] Starting Nextcloud AIO containers...${NC}"

cd "$PROJECT_DIR"
docker compose --file "$PROJECT_DIR/docker-compose.yml" --env-file "$PROJECT_DIR/.env" up -d

# Wait for container to be ready
echo -e "${YELLOW}Waiting for Nextcloud AIO to be ready...${NC}"
sleep 10

# Check status
if docker ps | grep -q nextcloud-aio-mastercontainer; then
    echo -e "${GREEN}✓ Container started successfully${NC}"
else
    echo -e "${RED}✗ Error: Container did not start${NC}"
    exit 1
fi

# ====== FINAL SUMMARY ======
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✓ Installation completed successfully${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Access AIO interface:"
echo -e "   ${YELLOW}https://localhost:8080${NC} (with self-signed certificate)"
echo ""
echo "2. Or if you have a domain configured:"
echo -e "   ${YELLOW}https://your-domain.com:8443${NC}"
echo ""
echo "3. Initial credentials:"
echo "   - Username: admin"
echo "   - Password: automatically generated (check in AIO interface)"
echo ""
echo "4. Project location:"
echo -e "   ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo "5. View logs:"
echo -e "   ${YELLOW}cd $PROJECT_DIR && docker compose logs -f${NC}"
echo ""
echo "6. Stop Nextcloud:"
echo -e "   ${YELLOW}cd $PROJECT_DIR && docker compose down${NC}"
echo ""
echo "7. Storage configuration:"
echo -e "   - Data: ${YELLOW}/mnt/nextcloud_storage${NC}"
echo -e "   - Backups: ${YELLOW}/mnt/nextcloud_backups${NC}"
echo ""