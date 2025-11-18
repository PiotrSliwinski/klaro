# GitHub Actions CI/CD Setup for Cloud Run

This guide explains how to set up automated deployment to Google Cloud Run using GitHub Actions.

## Overview

The GitHub Actions workflow will automatically:
- Build the Klaro Docker image
- Push it to Google Container Registry (GCR)
- Deploy to Cloud Run
- Display the service URL in the workflow summary

Deployments are triggered on:
- Push to `main` or `master` branch
- Manual trigger from GitHub UI

## Prerequisites

1. GitHub repository with the Klaro code
2. Google Cloud Platform project
3. GCP Service Account with appropriate permissions

## Setup Instructions

### Step 1: Create a GCP Service Account

1. Go to [GCP Console - IAM & Admin - Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)

2. Click "CREATE SERVICE ACCOUNT"

3. Fill in the details:
   - **Name**: `github-actions-deployer`
   - **Description**: `Service account for GitHub Actions to deploy to Cloud Run`

4. Click "CREATE AND CONTINUE"

5. Grant the following roles:
   - **Cloud Run Admin** (`roles/run.admin`)
   - **Service Account User** (`roles/iam.serviceAccountUser`)
   - **Storage Admin** (`roles/storage.admin`) - for GCR
   - **Cloud Build Editor** (`roles/cloudbuild.builds.editor`)

6. Click "CONTINUE" and then "DONE"

### Step 2: Create and Download Service Account Key

1. Find your newly created service account in the list

2. Click on it to open the details

3. Go to the "KEYS" tab

4. Click "ADD KEY" → "Create new key"

5. Select "JSON" format

6. Click "CREATE"

7. The key file will download automatically. **Keep this file secure!**

### Step 3: Enable Required GCP APIs

Run these commands in Google Cloud Shell or locally with gcloud:

```bash
# Set your project ID
export PROJECT_ID="your-project-id"

gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

### Step 4: Add GitHub Secrets

1. Go to your GitHub repository

2. Navigate to **Settings** → **Secrets and variables** → **Actions**

3. Click **New repository secret**

4. Add the following secrets:

#### Secret 1: GCP_PROJECT_ID
   - **Name**: `GCP_PROJECT_ID`
   - **Value**: Your Google Cloud project ID (e.g., `my-project-12345`)

#### Secret 2: GCP_SA_KEY
   - **Name**: `GCP_SA_KEY`
   - **Value**: The entire contents of the JSON key file you downloaded
   - Open the JSON file in a text editor and copy everything
   - Paste it into the secret value field

### Step 5: Customize the Workflow (Optional)

The workflow file is located at [.github/workflows/deploy-cloudrun.yml](.github/workflows/deploy-cloudrun.yml).

You can customize:

```yaml
env:
  SERVICE_NAME: klaro-consent      # Change service name
  REGION: us-central1              # Change region
```

Available regions:
- `us-central1` (Iowa)
- `us-east1` (South Carolina)
- `us-west1` (Oregon)
- `europe-west1` (Belgium)
- `asia-northeast1` (Tokyo)
- [See all regions](https://cloud.google.com/run/docs/locations)

### Step 6: Trigger Your First Deployment

#### Option A: Push to Main/Master Branch

```bash
git add .
git commit -m "Add Cloud Run deployment workflow"
git push origin main
```

#### Option B: Manual Trigger

1. Go to your GitHub repository
2. Click on **Actions** tab
3. Select **Deploy to Cloud Run** workflow
4. Click **Run workflow** button
5. Select the branch and click **Run workflow**

### Step 7: Monitor the Deployment

1. Go to the **Actions** tab in your GitHub repository

2. Click on the latest workflow run

3. Watch the progress of each step

4. Once complete, you'll see a summary with:
   - Service URL
   - Usage example
   - Deployment details

## Workflow File Explained

```yaml
name: Deploy to Cloud Run

# Trigger conditions
on:
  push:
    branches:
      - main
      - master
  workflow_dispatch:  # Manual trigger

# Environment variables
env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  SERVICE_NAME: klaro-consent
  REGION: us-central1

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      # 1. Checkout code from repository
      - name: Checkout code
        uses: actions/checkout@v4

      # 2. Authenticate with GCP
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      # 3. Set up gcloud CLI
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      # 4. Build Docker image
      - name: Build Docker image
        run: docker build -t IMAGE_NAME .

      # 5. Push to Google Container Registry
      - name: Push Docker image
        run: docker push IMAGE_NAME

      # 6. Deploy to Cloud Run
      - name: Deploy to Cloud Run
        run: gcloud run deploy ...

      # 7. Display service URL
      - name: Get Service URL
        run: echo "Service deployed!"
```

## Advanced Configuration

### Using Different Branches for Different Environments

You can modify the workflow to deploy to different environments:

```yaml
on:
  push:
    branches:
      - main        # Production
      - staging     # Staging environment

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # ... existing steps ...

      - name: Set environment
        run: |
          if [ "${{ github.ref }}" == "refs/heads/main" ]; then
            echo "SERVICE_NAME=klaro-prod" >> $GITHUB_ENV
          else
            echo "SERVICE_NAME=klaro-staging" >> $GITHUB_ENV
          fi
```

### Adding Build Tests

Add testing before deployment:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
      - run: npm ci
      - run: npm run lint
      - run: npm test

  deploy:
    needs: test  # Only deploy if tests pass
    runs-on: ubuntu-latest
    # ... rest of deploy job
```

### Using Workload Identity Federation (More Secure)

Instead of using service account keys, you can use Workload Identity Federation:

1. Set up Workload Identity Federation in GCP
2. Update the workflow:

```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID'
    service_account: 'github-actions@PROJECT_ID.iam.gserviceaccount.com'
```

[Learn more about Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)

### Custom Domain Deployment

After the first deployment, you can map a custom domain:

```yaml
- name: Map custom domain
  run: |
    gcloud run domain-mappings create \
      --service ${{ env.SERVICE_NAME }} \
      --domain klaro.yourdomain.com \
      --region ${{ env.REGION }}
```

## Troubleshooting

### Error: "Permission denied"

**Problem**: Service account lacks necessary permissions

**Solution**:
1. Go to IAM & Admin in GCP Console
2. Find your service account
3. Ensure it has these roles:
   - Cloud Run Admin
   - Service Account User
   - Storage Admin

### Error: "API not enabled"

**Problem**: Required GCP APIs are not enabled

**Solution**:
```bash
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### Error: "Invalid credentials"

**Problem**: The GCP_SA_KEY secret is incorrect

**Solution**:
1. Download a new JSON key from the service account
2. Update the GitHub secret with the new key
3. Make sure you copied the entire JSON content

### Workflow doesn't trigger

**Problem**: Workflow not running on push

**Solution**:
1. Check the branch name matches (`main` vs `master`)
2. Ensure the workflow file is in `.github/workflows/`
3. Check GitHub Actions is enabled for the repository

### Build fails with "npm ci" error

**Problem**: Dependencies can't be installed

**Solution**: This shouldn't happen with the Dockerfile since we're copying package files first. Check the Docker build logs.

## Monitoring and Logs

### View Workflow Logs

1. Go to **Actions** tab in GitHub
2. Click on a workflow run
3. Click on any step to see detailed logs

### View Cloud Run Logs

```bash
gcloud run services logs read klaro-consent \
  --region us-central1 \
  --limit 50
```

Or in GCP Console:
1. Go to [Cloud Run](https://console.cloud.google.com/run)
2. Click on your service
3. Click **LOGS** tab

## Security Best Practices

1. **Protect your secrets**: Never commit the service account key to git
2. **Use least privilege**: Only grant necessary IAM roles
3. **Rotate keys regularly**: Create new service account keys periodically
4. **Enable branch protection**: Require PR reviews before merging to main
5. **Use Workload Identity**: When possible, use Workload Identity Federation instead of keys
6. **Monitor deployments**: Set up alerts for deployment failures
7. **Review IAM policies**: Regularly audit service account permissions

## Cost Monitoring

Set up budget alerts in GCP:

1. Go to [Billing - Budgets & alerts](https://console.cloud.google.com/billing/budgets)
2. Create a budget
3. Set up email notifications
4. Monitor Cloud Run usage

## Rollback Strategy

If a deployment fails or causes issues:

### Option 1: Rollback via GitHub

1. Revert the commit that caused the issue
2. Push to trigger a new deployment

### Option 2: Rollback via gcloud

```bash
# List revisions
gcloud run revisions list \
  --service klaro-consent \
  --region us-central1

# Deploy a previous revision
gcloud run services update-traffic klaro-consent \
  --to-revisions REVISION_NAME=100 \
  --region us-central1
```

### Option 3: Rollback via GCP Console

1. Go to Cloud Run console
2. Click on your service
3. Go to **REVISIONS** tab
4. Click on a previous revision
5. Click **MANAGE TRAFFIC**
6. Set traffic to 100% for that revision

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Google GitHub Actions](https://github.com/google-github-actions)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Cloud Run Pricing](https://cloud.google.com/run/pricing)

## Support

For issues with:
- **GitHub Actions**: Check [GitHub Actions Status](https://www.githubstatus.com/)
- **Cloud Run**: Consult [Google Cloud Support](https://cloud.google.com/support)
- **Klaro**: Visit [Klaro GitHub Issues](https://github.com/kiprotect/klaro/issues)
