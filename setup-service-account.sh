#!/bin/bash

# Script to create and configure a GCP service account for Cloud Run deployments
# This script sets up all required IAM permissions for GitHub Actions

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== GCP Service Account Setup for Cloud Run ===${NC}\n"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Prompt for project ID
echo -e "${YELLOW}Please enter your Google Cloud Project ID:${NC}"
read -r PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID cannot be empty${NC}"
    exit 1
fi

# Service account details
SA_NAME="github-actions-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
SA_DISPLAY_NAME="GitHub Actions Deployer"
KEY_FILE="${SA_NAME}-key.json"

echo ""
echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Service Account: $SA_EMAIL"
echo "  Key File: $KEY_FILE"
echo ""

# Set the project
echo -e "${GREEN}Setting GCP project...${NC}"
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo -e "${GREEN}Enabling required APIs...${NC}"
gcloud services enable iam.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable serviceusage.googleapis.com

# Create service account
echo -e "${GREEN}Creating service account...${NC}"
if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    echo -e "${YELLOW}Service account already exists, skipping creation${NC}"
else
    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="$SA_DISPLAY_NAME" \
        --description="Service account for GitHub Actions to deploy to Cloud Run"
    echo "Service account created: $SA_EMAIL"
fi

# Grant IAM roles
echo -e "${GREEN}Granting IAM roles...${NC}"

roles=(
    "roles/run.admin"
    "roles/iam.serviceAccountUser"
    "roles/storage.admin"
    "roles/cloudbuild.builds.editor"
    "roles/serviceusage.serviceUsageConsumer"
    "roles/artifactregistry.admin"
)

for role in "${roles[@]}"; do
    echo "  Granting $role..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$role" \
        --condition=None \
        --quiet
done

# Create and download key
echo -e "${GREEN}Creating service account key...${NC}"
if [ -f "$KEY_FILE" ]; then
    echo -e "${YELLOW}Key file already exists: $KEY_FILE${NC}"
    echo -e "${YELLOW}Do you want to create a new key? (y/N):${NC}"
    read -r create_new_key
    if [[ ! "$create_new_key" =~ ^[Yy]$ ]]; then
        echo "Skipping key creation"
        KEY_FILE=""
    fi
fi

if [ -n "$KEY_FILE" ]; then
    gcloud iam service-accounts keys create "$KEY_FILE" \
        --iam-account="$SA_EMAIL"
    echo -e "${GREEN}Key created and saved to: $KEY_FILE${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Next steps for GitHub Actions:"
echo ""
echo "1. Go to your GitHub repository settings:"
echo "   https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions"
echo ""
echo "2. Add these secrets:"
echo "   - Name: GCP_PROJECT_ID"
echo "     Value: $PROJECT_ID"
echo ""
if [ -n "$KEY_FILE" ]; then
    echo "   - Name: GCP_SA_KEY"
    echo "     Value: (paste the entire contents of $KEY_FILE)"
    echo ""
    echo "3. To view the key contents, run:"
    echo "   cat $KEY_FILE"
    echo ""
    echo -e "${RED}IMPORTANT: Keep this key file secure and never commit it to git!${NC}"
fi
echo ""
echo "4. Push to your main/master branch to trigger deployment"
echo ""
