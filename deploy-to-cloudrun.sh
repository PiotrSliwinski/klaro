#!/bin/bash

# Klaro Cloud Run Deployment Script
# This script builds and deploys Klaro consent manager to Google Cloud Run

set -e  # Exit on error

# Configuration - Update these variables
PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
SERVICE_NAME="${SERVICE_NAME:-klaro-consent}"
REGION="${REGION:-us-central1}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Klaro Cloud Run Deployment ===${NC}\n"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Prompt for project ID if not set
if [ "$PROJECT_ID" = "your-project-id" ]; then
    echo -e "${YELLOW}Please enter your Google Cloud Project ID:${NC}"
    read -r PROJECT_ID
    IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
fi

echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Service Name: $SERVICE_NAME"
echo "  Region: $REGION"
echo "  Image: $IMAGE_NAME"
echo ""

# Set the project
echo -e "${GREEN}Setting GCP project...${NC}"
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo -e "${GREEN}Enabling required APIs...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Build the container image
echo -e "${GREEN}Building container image...${NC}"
gcloud builds submit --tag "$IMAGE_NAME" .

# Deploy to Cloud Run
echo -e "${GREEN}Deploying to Cloud Run...${NC}"
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_NAME" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --port 8080 \
  --memory 256Mi \
  --cpu 1 \
  --max-instances 10 \
  --min-instances 0

# Get the service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --platform managed --region "$REGION" --format 'value(status.url)')

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo "Your Klaro consent manager is now available at:"
echo -e "${GREEN}$SERVICE_URL${NC}"
echo ""
echo "Example usage in your HTML:"
echo "<script defer type=\"text/javascript\" src=\"$SERVICE_URL/config.js\"></script>"
echo "<script defer type=\"text/javascript\" src=\"$SERVICE_URL/klaro.js\"></script>"
echo ""
echo "Available files:"
echo "  - $SERVICE_URL/klaro.js (main file with CSS)"
echo "  - $SERVICE_URL/klaro-no-css.js (without CSS)"
echo "  - $SERVICE_URL/klaro.css (stylesheet)"
echo "  - $SERVICE_URL/klaro.min.css (minified stylesheet)"
echo "  - $SERVICE_URL/config.js (example config)"
echo ""
