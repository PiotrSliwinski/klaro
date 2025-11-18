# Klaro Cloud Run Deployment Guide

This guide will help you deploy Klaro consent manager to Google Cloud Run.

## Deployment Options

Choose the deployment method that works best for you:

1. **[GitHub Actions (Recommended for CI/CD)](#option-1-github-actions-cicd)** - Automated deployment on every push
2. **[Deployment Script](#option-2-using-the-deployment-script)** - Quick manual deployment with one command
3. **[Manual Deployment](#option-3-manual-deployment)** - Full control with gcloud commands

## Prerequisites

1. Google Cloud Platform account
2. [Google Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install) installed (for manual deployment)
3. Docker installed (optional, for local testing)
4. A GCP project with billing enabled

---

## Quick Deployment

### Option 1: GitHub Actions CI/CD

**Automatically deploy to Cloud Run whenever you push to your repository.**

This is the recommended approach for production deployments as it provides:
- Automated deployment on every push to main/master
- Manual deployment trigger from GitHub UI
- Deployment history and rollback capability
- No need for local gcloud installation

**Setup Steps:**

1. Follow the detailed guide: [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)

2. Quick summary:
   - Create a GCP service account with Cloud Run Admin permissions
   - Download the JSON key
   - Add `GCP_PROJECT_ID` and `GCP_SA_KEY` as GitHub secrets
   - Push to main/master branch to trigger deployment

3. Monitor deployment in the GitHub Actions tab

See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for complete instructions, troubleshooting, and advanced configuration.

### Option 2: Using the Deployment Script

1. Make sure you're authenticated with Google Cloud:
   ```bash
   gcloud auth login
   ```

2. Run the deployment script:
   ```bash
   ./deploy-to-cloudrun.sh
   ```

3. When prompted, enter your Google Cloud Project ID

4. The script will:
   - Enable required APIs (Cloud Build, Cloud Run, Container Registry)
   - Build the Docker image
   - Deploy to Cloud Run
   - Display the service URL

### Option 3: Manual Deployment

1. Set your project ID:
   ```bash
   export PROJECT_ID="your-project-id"
   export SERVICE_NAME="klaro-consent"
   export REGION="us-central1"
   ```

2. Enable required services:
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable run.googleapis.com
   gcloud services enable containerregistry.googleapis.com
   ```

3. Build and submit the container image:
   ```bash
   gcloud builds submit --tag gcr.io/${PROJECT_ID}/${SERVICE_NAME}
   ```

4. Deploy to Cloud Run:
   ```bash
   gcloud run deploy ${SERVICE_NAME} \
     --image gcr.io/${PROJECT_ID}/${SERVICE_NAME} \
     --platform managed \
     --region ${REGION} \
     --allow-unauthenticated \
     --port 8080 \
     --memory 256Mi \
     --cpu 1
   ```

5. Get your service URL:
   ```bash
   gcloud run services describe ${SERVICE_NAME} \
     --platform managed \
     --region ${REGION} \
     --format 'value(status.url)'
   ```

## Local Testing

Before deploying to Cloud Run, you can test the Docker container locally:

1. Build the image:
   ```bash
   docker build -t klaro-local .
   ```

2. Run the container:
   ```bash
   docker run -p 8080:8080 klaro-local
   ```

3. Access the service at: http://localhost:8080

4. Test the available files:
   - http://localhost:8080/klaro.js
   - http://localhost:8080/klaro.css
   - http://localhost:8080/config.js
   - http://localhost:8080/index.html

## Using Klaro from Cloud Run

Once deployed, you can use Klaro in your website by including the scripts from your Cloud Run URL:

```html
<!-- Replace YOUR_CLOUDRUN_URL with your actual Cloud Run service URL -->
<script defer type="text/javascript" src="YOUR_CLOUDRUN_URL/config.js"></script>
<script defer type="text/javascript" src="YOUR_CLOUDRUN_URL/klaro.js"></script>
```

### Available Files

Your Cloud Run deployment serves all files from the `dist` folder:

- `/klaro.js` - Main Klaro file with CSS included
- `/klaro-no-css.js` - Klaro without CSS
- `/klaro.css` - Full stylesheet
- `/klaro.min.css` - Minified stylesheet
- `/config.js` - Example configuration file
- `/klaro-no-translations.js` - Klaro without translations
- Additional variants and assets in the `/dist` folder

### Custom Configuration

1. Create your own `config.js` file based on the example in `dist/config.js`
2. Host it on your own server or include it inline in your HTML
3. Load it before loading the Klaro script

Example:
```html
<!-- Your custom config -->
<script defer type="text/javascript" src="/your-custom-config.js"></script>
<!-- Klaro from Cloud Run -->
<script defer type="text/javascript" src="YOUR_CLOUDRUN_URL/klaro.js"></script>
```

## Configuration Options

### Environment Variables

You can customize the deployment by setting these environment variables before running the script:

- `GCP_PROJECT_ID` - Your Google Cloud project ID
- `SERVICE_NAME` - Name for your Cloud Run service (default: `klaro-consent`)
- `REGION` - GCP region for deployment (default: `us-central1`)

Example:
```bash
export GCP_PROJECT_ID="my-project-123"
export SERVICE_NAME="cookie-consent"
export REGION="europe-west1"
./deploy-to-cloudrun.sh
```

### Custom Domain

To use a custom domain with your Cloud Run service:

1. Deploy your service
2. Go to Cloud Run console
3. Click on your service
4. Click "MANAGE CUSTOM DOMAINS"
5. Follow the instructions to map your domain

### CORS Configuration

The nginx configuration includes basic CORS headers that allow any origin. To restrict access, modify the `Dockerfile` and update the `add_header Access-Control-Allow-Origin` directive:

```nginx
# Allow only specific domain
add_header Access-Control-Allow-Origin "https://yourdomain.com";
```

## Updating the Deployment

To update your deployment with new changes:

1. Make your changes to the code
2. Run the deployment script again:
   ```bash
   ./deploy-to-cloudrun.sh
   ```

The script will rebuild and redeploy automatically.

## Monitoring and Logs

View logs for your Cloud Run service:

```bash
gcloud run services logs read ${SERVICE_NAME} \
  --platform managed \
  --region ${REGION} \
  --limit 50
```

Or use the Cloud Console:
1. Go to [Cloud Run Console](https://console.cloud.google.com/run)
2. Click on your service
3. Click on "LOGS" tab

## Cost Optimization

Cloud Run pricing is based on:
- CPU and memory allocation (only while processing requests)
- Number of requests
- Network egress

For Klaro (a lightweight static file server):
- Recommended: 256Mi memory, 1 CPU
- Expected cost: Very low (likely within free tier for moderate traffic)
- Min instances: 0 (no cost when idle)
- Max instances: 10 (adjust based on your needs)

Free tier includes:
- 2 million requests/month
- 360,000 GB-seconds of memory
- 180,000 vCPU-seconds

## Troubleshooting

### Build Fails

If the build fails:
1. Check your Docker installation
2. Verify all files are present
3. Check build logs: `gcloud builds list`

### Deployment Fails

If deployment fails:
1. Verify APIs are enabled
2. Check IAM permissions
3. Review error messages in Cloud Console

### CORS Issues

If you encounter CORS issues:
1. Check the nginx configuration in `Dockerfile`
2. Ensure proper `Access-Control-Allow-Origin` headers
3. Test with browser developer tools

### Service Not Accessible

1. Verify the service is deployed: `gcloud run services list`
2. Check if `--allow-unauthenticated` was set
3. Verify firewall/network settings

## Security Considerations

1. **Authentication**: By default, the service is publicly accessible (`--allow-unauthenticated`). If you need to restrict access, remove this flag and configure authentication.

2. **HTTPS**: Cloud Run automatically provides HTTPS. Always use HTTPS URLs when embedding Klaro.

3. **Rate Limiting**: Consider adding rate limiting if you expect high traffic or want to prevent abuse.

4. **Content Security Policy**: Ensure your website's CSP allows loading scripts from your Cloud Run domain.

## Additional Resources

- [Klaro Documentation](https://heyklaro.com/docs/)
- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Run Pricing](https://cloud.google.com/run/pricing)
- [Klaro GitHub Repository](https://github.com/kiprotect/klaro)

## Support

For Klaro-specific issues, visit the [Klaro GitHub Issues](https://github.com/kiprotect/klaro/issues).

For Cloud Run issues, consult the [Google Cloud Support](https://cloud.google.com/support).
