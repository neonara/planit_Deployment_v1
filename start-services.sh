#!/bin/bash

set -e

echo "🚀 Starting PlanIt Application Services..."
echo "================================================"

# ---------------- Colors ----------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --------------- Output Helpers ----------------
log() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} 📋 $1"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ✅ $1"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} ⚠️  $1"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ❌ $1"; }
info() { echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} 💡 $1"; }

# --------------- Argument Parsing ----------------
CLEANUP_MODE="prompt"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-cleanup|-n) CLEANUP_MODE="skip"; shift ;;
        --force-cleanup|-f) CLEANUP_MODE="force"; shift ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "  --no-cleanup, -n    Skip cleanup"
            echo "  --force-cleanup, -f Cleanup without prompt"
            echo "  --help, -h          Show help"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------------- Core Functions ----------------
trap 'warn "Received interrupt signal. Shutting down..."; docker-compose down; exit 1' INT TERM

check_prereqs() {
    log "Checking prerequisites..."
    for cmd in docker docker-compose; do
        command -v $cmd &>/dev/null || { error "$cmd not found in PATH"; exit 1; }
    done
    docker info &>/dev/null || { error "Docker daemon not running"; exit 1; }
    success "All prerequisites satisfied"
}

load_env() {
    if [[ -f .env ]]; then
        export $(grep -v '^#' .env | xargs)
        success "Environment variables loaded"
    else
        warn ".env file not found"
    fi
}

handle_cleanup() {
    case "$CLEANUP_MODE" in
        skip)
            info "Skipping cleanup (--no-cleanup)"
            ;;
        force)
            log "Force cleanup..."
            docker-compose down --remove-orphans &>/dev/null || true
            cleanup_docker_cache
            success "Cleanup done"
            ;;
        prompt)
            read -rp "🧹 Clean up existing containers? (Y/n): " res
            [[ "$res" =~ ^[Nn]$ ]] && info "Skipping cleanup" && return
            log "Cleaning up..."
            docker-compose down --remove-orphans &>/dev/null || true
            cleanup_docker_cache
            success "Cleanup complete"
            ;;
    esac
}

cleanup_docker_cache() {
    log "Cleaning Docker cache and dangling images..."
    docker system prune -f &>/dev/null || true
    docker image prune -f &>/dev/null || true
    # Remove any corrupted backend images
    docker rmi planit_backend:latest &>/dev/null || true
    success "Docker cache cleaned"
}

fix_celery_permissions() {
    log "Fixing Celery beat schedule file permissions..."
    # Ensure the celerybeat-schedule file has proper permissions
    if [[ -f "backend/celerybeat-schedule" ]]; then
        chmod 755 backend/celerybeat-schedule || warn "Could not change celerybeat-schedule permissions"
    else
        # Create the file with proper permissions if it doesn't exist
        touch backend/celerybeat-schedule && chmod 755 backend/celerybeat-schedule || warn "Could not create celerybeat-schedule"
    fi
    success "Celery permissions fixed"
}

fix_container_config_error() {
    log "Fixing ContainerConfig error..."
    # Stop all containers
    docker-compose down --remove-orphans &>/dev/null || true
    
    # Remove problematic containers and images
    docker container prune -f &>/dev/null || true
    docker rmi planit_backend:latest &>/dev/null || true
    docker rmi $(docker images -f "dangling=true" -q) &>/dev/null || true
    
    # Clear Docker builder cache
    docker builder prune -f &>/dev/null || true
    
    success "ContainerConfig error fixed"
}

wait_for() {
    local svc="$1" port="$2" max="${3:-50}" count=1
    log "Waiting for $svc on port $port..."
    while [[ $count -le $max ]]; do
        nc -z localhost "$port" &>/dev/null && { success "$svc is up"; return 0; }
        sleep 2; ((count++))
    done
    error "$svc failed to respond on port $port"
    return 1
}

wait_for_pg_ready() {
    log "Waiting for PostgreSQL readiness..."
    for i in {1..30}; do
        docker-compose exec -T postgres psql -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-planit_db}" -c "SELECT 1" &>/dev/null && {
            success "PostgreSQL ready!"
            return
        }
        sleep 2
    done
    error "PostgreSQL did not become ready"
    exit 1
}

setup_postgres() {
    log "Creating DB/user if needed..."
    # Use the actual environment variables or defaults
    local pg_user="${POSTGRES_USER:-postgres}"
    local pg_password="${POSTGRES_PASSWORD:-root}"
    local pg_db="${POSTGRES_DB:-planit_db}"
    
    # Connect as the main postgres user to create database and user if needed
    docker-compose exec -T postgres psql -U postgres -d postgres -c "
        DO \$\$ BEGIN
            -- Create database if it doesn't exist
            IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${pg_db}') THEN
                CREATE DATABASE ${pg_db};
            END IF;
            
            -- Create user if it doesn't exist and it's not postgres
            IF '${pg_user}' != 'postgres' AND NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${pg_user}') THEN
                CREATE USER ${pg_user} WITH PASSWORD '${pg_password}';
                GRANT ALL PRIVILEGES ON DATABASE ${pg_db} TO ${pg_user};
                ALTER USER ${pg_user} CREATEDB;
            END IF;
        END \$\$;
    " || warn "DB setup may have already been done"
    success "PostgreSQL database & user initialized"
}

# ---------------- Startup Sequence ----------------
main() {
    cd "$(dirname "$0")"
    check_prereqs
    load_env
    handle_cleanup
    # fix_celery_permissions

    log "Starting core services..."
    docker-compose up -d redis postgres
    wait_for redis 6380
    wait_for postgres 5433
    wait_for_pg_ready
    setup_postgres

    log "Starting backend ..."
    docker-compose up -d backend
    wait_for backend 8080

    log "Starting Celery services..."
    docker-compose up -d celery_worker celery_beat
    sleep 2

    log "Starting frontend..."
    docker-compose up -d frontend
    wait_for frontend 3100

    log "Starting Nginx..."
    docker-compose up -d nginx
    wait_for nginx 8081

    echo "================================================"
    success "🎉 PlanIt Application Started Successfully!"
    echo "================================================"
    echo ""
    info "🌍 App:         http://localhost:8081"
    info "⚛️  Frontend:    http://localhost:3100"
    info "🔧 Backend:     http://localhost:8080"
    info "👤 Admin:       http://localhost:8080/admin"
    info "📊 Docs:        http://localhost:8080/api/docs"
    echo ""
    info "🐘 PostgreSQL:  localhost:5433"
    info "🔴 Redis:       localhost:6380"
    echo ""
    info "📝 Commands:"
    echo "• Logs:         docker-compose logs -f"
    echo "• Status:       docker-compose ps"
    echo "• Stop:         ./stop-services.sh"
    echo "• Restart:      docker-compose restart [service]"
    echo ""

    read -rp "📋 Follow logs now? (y/N): " logs
    [[ "$logs" =~ ^[Yy]$ ]] && docker-compose logs -f
}

main "$@"