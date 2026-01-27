#!/bin/bash
# Build and run the docker container locally with Azure credentials

# Resolve the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Resolve the project root relative to the script
PROJECT_ROOT="$SCRIPT_DIR/.."

SP_FILE="$PROJECT_ROOT/sp-output.json"

if [ ! -f "$SP_FILE" ]; then
    echo "Error: $SP_FILE not found. Please ensure sp-output.json exists in the project root."
    exit 1
fi

CLIENT_ID=$(grep -o '"clientId": "[^"]*' "$SP_FILE" | grep -o '[^"]*$')
CLIENT_SECRET=$(grep -o '"clientSecret": "[^"]*' "$SP_FILE" | grep -o '[^"]*$')
TENANT_ID=$(grep -o '"tenantId": "[^"]*' "$SP_FILE" | grep -o '[^"]*$')

# Retrieve Storage Account Name from Terraform output or hardcode if known
# For now, hardcoding based on previous context "pappudevpdfsa"
STORAGE_ACCOUNT_NAME="pappudevpdfsa"

echo "Building Docker image..."
# Build from the project root using the api directory
docker build -t pappu-api "$PROJECT_ROOT/api"

echo "Running Docker container..."
echo "Service will be available at http://localhost:8000"
echo "Press Ctrl+C to stop."

docker run --rm -p 8000:8000 \
  -e AZURE_CLIENT_ID="$CLIENT_ID" \
  -e AZURE_CLIENT_SECRET="$CLIENT_SECRET" \
  -e AZURE_TENANT_ID="$TENANT_ID" \
  -e STORAGE_ACCOUNT_NAME="$STORAGE_ACCOUNT_NAME" \
  pappu-api
