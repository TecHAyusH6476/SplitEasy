# SplitEasy Backend - Google Cloud Run Deployment Guide

This guide will help you deploy the SplitEasy backend to Google Cloud Run using Application Default Credentials (ADC) and Cloud Build.

## Prerequisites

1. **Google Cloud Account**: You need a Google Cloud account with billing enabled
2. **gcloud CLI**: Install the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
3. **Application Default Credentials**: Set up ADC for authentication
4. **MongoDB Database**: You'll need a MongoDB database (MongoDB Atlas recommended)

## Setup Instructions

### 1. Authentication Setup

First, authenticate with Google Cloud using Application Default Credentials:

```bash
# Login to Google Cloud
gcloud auth login

# Set your project ID
gcloud config set project YOUR_PROJECT_ID

# Enable Application Default Credentials
gcloud auth application-default login
```

### 2. Create Secrets in Secret Manager

Create the required secrets for your application:

```bash
# MongoDB URI
echo "mongodb+srv://username:password@cluster.mongodb.net/spliteasy" | gcloud secrets create mongodb-uri --data-file=-

# JWT Secret (generate a strong secret)
echo "your-super-secret-jwt-key-here" | gcloud secrets create jwt-secret --data-file=-

# CORS Origins (comma-separated list of allowed origins)
echo "https://your-frontend-domain.com,https://localhost:3000" | gcloud secrets create cors-origins --data-file=-
```

### 3. Deploy to Cloud Run

#### Option A: Using the Deployment Script (Recommended)

Make the deployment script executable and run it:

```bash
chmod +x deploy-cloud-run.sh
./deploy-cloud-run.sh
```

#### Option B: Manual Deployment

1. **Build and push the image**:

```bash
# Build the image
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/spliteasy-backend

# Deploy to Cloud Run
gcloud run deploy spliteasy-backend \
  --image gcr.io/YOUR_PROJECT_ID/spliteasy-backend \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --port 3001 \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --set-env-vars NODE_ENV=production,PORT=3001 \
  --set-secrets MONGODB_URI=mongodb-uri:latest,JWT_SECRET=jwt-secret:latest,CORS_ORIGINS=cors-origins:latest
```

### 4. Verify Deployment

After deployment, test your service:

```bash
# Get the service URL
SERVICE_URL=$(gcloud run services describe spliteasy-backend --region=us-central1 --format="value(status.url)")

# Test health endpoint
curl $SERVICE_URL/api/users/health
```

## Configuration Files

### cloudbuild.yaml

This file defines the Cloud Build pipeline that:

- Builds the Docker image
- Pushes it to Google Container Registry
- Deploys it to Cloud Run with proper configuration

### Dockerfile

Optimized for Cloud Run with:

- Multi-stage build for smaller image size
- Non-root user for security
- Health check endpoint
- Proper port configuration

### .dockerignore

Excludes unnecessary files from the Docker build context to reduce build time and image size.

## Environment Variables

The following environment variables are automatically set from Secret Manager:

- `MONGODB_URI`: Your MongoDB connection string
- `JWT_SECRET`: Secret key for JWT token signing
- `CORS_ORIGINS`: Comma-separated list of allowed CORS origins

## Monitoring and Logs

### View Logs

```bash
# View recent logs
gcloud logs read --project YOUR_PROJECT_ID

# Follow logs in real-time
gcloud logs tail --follow --project YOUR_PROJECT_ID
```

### Monitor Performance

- Go to [Google Cloud Console](https://console.cloud.google.com)
- Navigate to Cloud Run
- Select your service to view metrics and logs

## Updating the Service

To update your service with new code:

1. **Push your changes to Git**
2. **Run the deployment script again**:
   ```bash
   ./deploy-cloud-run.sh
   ```

Or manually trigger a new build:

```bash
gcloud builds submit --config cloudbuild.yaml
```

## Troubleshooting

### Common Issues

1. **Build fails**: Check that all dependencies are in package.json
2. **Service won't start**: Check the logs for environment variable issues
3. **Health check fails**: Ensure the health endpoint is accessible
4. **CORS errors**: Verify CORS_ORIGINS secret is set correctly

### Debug Commands

```bash
# Check service status
gcloud run services describe spliteasy-backend --region=us-central1

# View build logs
gcloud builds list --limit=5

# Check secrets
gcloud secrets list
```

## Cost Optimization (Student-Friendly)

- **Min instances**: Set to 1 to keep costs predictable
- **Max instances**: Set to 1 to prevent automatic scaling and unexpected charges
- **Memory**: Reduced to 256Mi to minimize costs
- **CPU**: Single CPU core to keep costs low
- **Region**: Choose the region closest to your users

## Security Best Practices

1. **Secrets**: Never commit secrets to code - use Secret Manager
2. **CORS**: Restrict CORS origins to your actual domains
3. **Authentication**: Implement proper JWT validation
4. **HTTPS**: Cloud Run automatically provides HTTPS
5. **IAM**: Use least privilege principle for service accounts

## Support

If you encounter issues:

1. Check the [Google Cloud Run documentation](https://cloud.google.com/run/docs)
2. Review the logs for error messages
3. Verify your secrets are correctly configured
4. Ensure your MongoDB database is accessible from Cloud Run
