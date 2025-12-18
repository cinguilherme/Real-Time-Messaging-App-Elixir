#!/bin/sh
# MinIO Bucket Initialization Script
# This script runs after MinIO starts to create the required bucket

set -e

echo "Waiting for MinIO to be ready..."
sleep 5

# Configure MinIO client
mc alias set myminio http://s3_minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}

# Create bucket if it doesn't exist
if ! mc ls myminio/messaging-blobs > /dev/null 2>&1; then
    echo "Creating bucket: messaging-blobs"
    mc mb myminio/messaging-blobs
    echo "Setting public download policy for bucket"
    mc anonymous set download myminio/messaging-blobs
    echo "Bucket created successfully"
else
    echo "Bucket messaging-blobs already exists"
fi

echo "MinIO initialization complete"
