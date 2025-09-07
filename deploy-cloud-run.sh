#!/bin/bash

# SplitEasy Backend - Cloud Run Deployment Script
# This script deploys the backend to Google Cloud Run using Cloud Build

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="vibodh-app"
REGION="asia-east1"
SERVICE_NAME="spliteasy-backend"
IMAGE_NAME="gcr.io/$PROJECT_ID/spliteasy-backend"

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

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    print_error "No active gcloud authentication found. Please run 'gcloud auth login' first."
    exit 1
fi

# Get project ID if not set
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        print_error "No project ID found. Please set it manually or run 'gcloud config set project YOUR_PROJECT_ID'"
        exit 1
    fi
    print_status "Using project ID: $PROJECT_ID"
fi

# Enable required APIs
print_status "Enabling required Google Cloud APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Set up secrets in Secret Manager (if they don't exist)
print_status "Setting up secrets in Secret Manager..."

# Check if secrets exist, if not, prompt user to create them
if ! gcloud secrets describe mongodb-uri &> /dev/null; then
    print_warning "MongoDB URI secret not found. Please create it:"
    echo "gcloud secrets create mongodb-uri --data-file=- <<< 'your-mongodb-connection-string'"
fi

if ! gcloud secrets describe jwt-secret &> /dev/null; then
    print_warning "JWT Secret not found. Please create it:"
    echo "gcloud secrets create jwt-secret --data-file=- <<< 'your-jwt-secret'"
fi

if ! gcloud secrets describe cors-origins &> /dev/null; then
    print_warning "CORS Origins secret not found. Please create it:"
    echo "gcloud secrets create cors-origins --data-file=- <<< 'your-cors-origins'"
fi

# Build and deploy using Cloud Build
print_status "Building and deploying to Cloud Run..."
gcloud builds submit --config cloudbuild.yaml --project $PROJECT_ID

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)" --project $PROJECT_ID)

print_status "Deployment completed successfully!"
print_status "Service URL: $SERVICE_URL"
print_status "You can view logs with: gcloud logs tail --follow --project $PROJECT_ID"

# Test the deployment
print_status "Testing the deployment..."
if curl -f -s "$SERVICE_URL/api/users/health" > /dev/null; then
    print_status "Health check passed! Service is running correctly."
else
    print_warning "Health check failed. Please check the logs for issues."
fi

echo ""
print_status "Deployment Summary:"
echo "  Project ID: $PROJECT_ID"
echo "  Service Name: $SERVICE_NAME"
echo "  Region: $REGION"
echo "  Service URL: $SERVICE_URL"
echo ""
print_status "To update the service, simply run this script again."
