#!/bin/bash

# Fetch CRDs from GitHub
VELERO_VERSION="11.3.1"
VELERO_CRDS_URL="https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-${VELERO_VERSION}/charts/velero/crds"
GITHUB_API_URL="https://api.github.com/repos/vmware-tanzu/helm-charts/contents/charts/velero/crds?ref=velero-${VELERO_VERSION}"
CRDS_DIR="crds"

mkdir -p "$CRDS_DIR"

# Get list of CRD files from GitHub API
crd_files=$(curl -s "$GITHUB_API_URL" | jq -r '.[].name' | grep '.yaml$')

if [ -z "$crd_files" ]; then
    echo "Error: Could not fetch CRD file list from GitHub API"
    exit 1
fi

# Download each CRD file
for crd_file in $crd_files; do
    echo "Downloading $crd_file..."
    curl -s "${VELERO_CRDS_URL}/$crd_file" -o "${CRDS_DIR}/$crd_file" || (echo "Failed to download $crd_file"; exit 1)
done

echo "All CRDs fetched successfully to ${CRDS_DIR}/"