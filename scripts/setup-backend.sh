#!/bin/bash

# Script to set up Azure Storage Account for Terraform backend
# Run this once before the first Terraform deployment

set -e

RESOURCE_GROUP="pappu-terraform-state-rg"
STORAGE_ACCOUNT="papputerraformstate"
CONTAINER_NAME="tfstate"
LOCATION="westeurope"

echo "Setting up Terraform backend storage account..."
echo ""

# Check if logged in and validate subscription
if ! az account show &>/dev/null; then
    echo "❌ Error: Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Get and display current subscription
CURRENT_SUB=$(az account show --query "{Name:name, SubscriptionId:id}" -o json 2>/dev/null)
if [ -z "$CURRENT_SUB" ]; then
    echo "❌ Error: Could not retrieve current subscription."
    echo ""
    echo "Available subscriptions:"
    az account list --query "[].{Name:name, SubscriptionId:id, IsDefault:isDefault}" -o table
    echo ""
    echo "Please set a subscription:"
    echo "   az account set --subscription '<subscription-id-or-name>'"
    exit 1
fi

SUBSCRIPTION_NAME=$(echo $CURRENT_SUB | grep -o '"Name": "[^"]*' | cut -d'"' -f4)
SUBSCRIPTION_ID=$(echo $CURRENT_SUB | grep -o '"SubscriptionId": "[^"]*' | cut -d'"' -f4)

echo "✅ Using subscription:"
echo "   Name: $SUBSCRIPTION_NAME"
echo "   ID: $SUBSCRIPTION_ID"
echo ""

# Check if resource group exists, create if not
if ! az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "Creating resource group: $RESOURCE_GROUP"
    az group create --name $RESOURCE_GROUP --location $LOCATION
else
    echo "Resource group $RESOURCE_GROUP already exists"
fi

# Check if storage account exists, create if not
if ! az storage account show --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP &>/dev/null; then
    echo "Creating storage account: $STORAGE_ACCOUNT"
    az storage account create \
        --resource-group $RESOURCE_GROUP \
        --name $STORAGE_ACCOUNT \
        --sku Standard_LRS \
        --encryption-services blob \
        --location $LOCATION
    
    echo "Waiting for storage account to be ready..."
    sleep 10
else
    echo "Storage account $STORAGE_ACCOUNT already exists"
fi

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
    --resource-group $RESOURCE_GROUP \
    --account-name $STORAGE_ACCOUNT \
    --query "[0].value" -o tsv)

# Check if container exists, create if not
if ! az storage container show \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY &>/dev/null; then
    echo "Creating container: $CONTAINER_NAME"
    az storage container create \
        --name $CONTAINER_NAME \
        --account-name $STORAGE_ACCOUNT \
        --account-key $STORAGE_KEY \
        --public-access off
else
    echo "Container $CONTAINER_NAME already exists"
fi

echo ""
echo "✅ Backend storage account setup complete!"
echo ""
echo "Next steps:"
echo "1. Copy terraform/backend.tf.example to terraform/backend.tf"
echo "2. Update backend.tf with your values if different"
echo "3. Run 'terraform init' to initialize the backend"
