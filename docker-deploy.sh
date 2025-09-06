#!/bin/bash

# Docker deployment script for SplitEasy backend with MongoDB Atlas
# Usage: ./docker-deploy.sh [start|stop|restart|logs|status|clean]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to check if Docker Compose is available
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        print_status "Using docker-compose command"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        print_status "Using docker compose command"
    else
        print_error "Docker Compose is not installed. Please install it and try again."
        exit 1
    fi
}

# Function to create logs directory
create_logs_dir() {
    if [ ! -d "logs" ]; then
        mkdir -p logs
        print_status "Created logs directory"
    fi
}

# Function to load environment variables
load_env() {
    if [ -f ".env" ]; then
        print_status "Loading environment variables from .env file"
        export $(cat .env | grep -v '^#' | xargs)
    else
        print_error "No .env file found. Please create one based on env.example"
        exit 1
    fi
}

# Function to validate environment variables
validate_env() {
    if [ -z "$MONGODB_URI" ]; then
        print_error "MONGODB_URI is required. Please set it in your .env file"
        exit 1
    fi
    
    if [ -z "$JWT_SECRET" ]; then
        print_error "JWT_SECRET is required. Please set it in your .env file"
        exit 1
    fi
    
    print_status "Environment variables validated successfully"
}

# Function to start services
start_services() {
    print_status "Starting SplitEasy backend services..."
    create_logs_dir
    load_env
    validate_env
    
    # Build and start services
    $DOCKER_COMPOSE_CMD up --build -d
    
    print_status "Services started successfully!"
    print_status "Backend API: http://localhost:3001"
    print_status "View logs: ./docker-deploy.sh logs"
}

# Function to stop services
stop_services() {
    print_status "Stopping services..."
    $DOCKER_COMPOSE_CMD down
    print_status "Services stopped"
}

# Function to restart services
restart_services() {
    print_status "Restarting services..."
    stop_services
    start_services
}

# Function to show status
show_status() {
    print_status "Checking service status..."
    echo ""
    
    # Check running containers
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # Check container health
    echo "Container health:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(healthy|unhealthy|starting)"
}

# Function to show logs
show_logs() {
    local service=${1:-"backend"}
    print_status "Showing logs for $service service..."
    $DOCKER_COMPOSE_CMD logs -f "$service"
}

# Function to clean up containers, images, and volumes
clean_up() {
    print_warning "This will remove all containers, images, and volumes. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_status "Cleaning up Docker resources..."
        stop_services
        
        # Remove containers
        docker container prune -f
        
        # Remove images
        docker image prune -a -f
        
        # Remove volumes
        docker volume prune -f
        
        # Remove networks
        docker network prune -f
        
        print_status "Cleanup completed"
    else
        print_status "Cleanup cancelled"
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the backend services"
    echo "  stop      Stop all services"
    echo "  restart   Restart all services"
    echo "  logs      Show logs for a specific service (default: backend)"
    echo "  status    Show service status"
    echo "  clean     Clean up Docker resources (containers, images, volumes)"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start       # Start services"
    echo "  $0 logs        # Show backend logs"
    echo "  $0 status      # Show service status"
    echo ""
    echo "Note: Make sure to create a .env file with your MongoDB Atlas connection string"
}

# Main script logic
main() {
    check_docker
    check_docker_compose
    
    case "${1:-help}" in
        "start")
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "logs")
            show_logs "$2"
            ;;
        "status")
            show_status
            ;;
        "clean")
            clean_up
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@" 