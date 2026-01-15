# Pappu - Azure Infrastructure Deployment

This project contains Terraform configurations to deploy Azure infrastructure resources including:
- Resource Group
- Virtual Network with Application Subnet
- Storage Account for PDF uploads
- Key Vault for secrets management

## Prerequisites

### For Local Development

1. **Azure Account**: An active Azure subscription
2. **Azure CLI**: Installed and configured
3. **Terraform**: Version >= 1.5.0

### Install Prerequisites (macOS)

```bash
# Install Azure CLI
brew install azure-cli

# Install Terraform
brew install terraform
```

### For CI/CD Pipeline Setup

1. **GitHub Repository**: Your code pushed to GitHub
2. **Azure Service Principal**: For GitHub Actions to authenticate with Azure
3. **Terraform Backend Storage**: Azure Storage Account for Terraform state (one-time setup)

## CI/CD Deployment Setup

This project uses **GitHub Actions** for automated Terraform deployments. The pipeline will:
- **Plan** on Pull Requests (shows what will change)
- **Apply** on merge to `main` branch (deploys infrastructure)

### Step 1: Create Azure Service Principal for GitHub Actions

Create a service principal that GitHub Actions will use to authenticate with Azure:

**Recommended Method (Two-Step):**

```bash
# Login to Azure
az login

# Step 1: Create service principal (without role assignment)
az ad sp create-for-rbac \
  --name "pappu-github-actions" \
  --skip-assignment \
  --output json > sp-output.json

# Step 2: Get the appId
APP_ID=$(cat sp-output.json | jq -r '.appId' || cat sp-output.json | grep -o '"appId": "[^"]*' | cut -d'"' -f4)

# Step 3: Get subscription ID and assign Contributor role
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID

# Step 4: View and save the credentials
cat sp-output.json
```

**Alternative One-Step Method (if subscription ID is available):**

```bash
az login
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az ad sp create-for-rbac \
  --name "pappu-github-actions" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --output json
```

**Save the JSON output** - it contains `appId` (clientId), `password` (clientSecret), `tenant`, and `subscriptionId`. You'll need these for GitHub Secrets.

### Step 2: Set Up Terraform Backend Storage (One-Time Setup)

The Terraform state needs to be stored in Azure Storage. Run the setup script:

```bash
# Make script executable (if not already)
chmod +x scripts/setup-backend.sh

# Run the setup script
./scripts/setup-backend.sh
```

This creates:
- Resource Group: `pappu-terraform-state-rg`
- Storage Account: `papputerraformstate`
- Container: `tfstate`

**Note**: If the storage account name is taken, edit `scripts/setup-backend.sh` with a unique name.

### Step 3: Configure Terraform Backend

Copy the example backend configuration:

```bash
cp terraform/backend.tf.example terraform/backend.tf
```

Edit `terraform/backend.tf` if you used different names in the setup script.

### Step 4: Configure GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID | From `az account show --query id -o tsv` OR JSON `subscriptionId` |
| `AZURE_CLIENT_ID` | `appId` from Step 1 | From the service principal JSON output |
| `AZURE_CLIENT_SECRET` | `password` from Step 1 | From the service principal JSON output |
| `AZURE_TENANT_ID` | `tenant` from Step 1 | From the service principal JSON output |

**To get your subscription ID:**
```bash
az account show --query id -o tsv
```

### Step 5: Push to GitHub

```bash
# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit with CI/CD setup"

# Add remote (replace with your GitHub repo URL)
git remote add origin https://github.com/YOUR_USERNAME/Pappu.git

# Push to main branch
git branch -M main
git push -u origin main
```

### Step 6: Verify CI/CD Pipeline

1. **Check Actions Tab**: Go to your GitHub repo → **Actions** tab
2. **First Run**: The `terraform-apply` workflow will run on the push to `main`
3. **Test PR**: Create a pull request to see the `terraform-plan` workflow in action

## How CI/CD Works

### Terraform Plan Workflow (`.github/workflows/terraform-plan.yml`)
- **Triggers**: Pull Requests with changes to `terraform/` directory
- **Actions**:
  - Validates Terraform syntax
  - Runs `terraform plan`
  - Comments the plan on the PR

### Terraform Apply Workflow (`.github/workflows/terraform-apply.yml`)
- **Triggers**: 
  - Push to `main` branch with changes to `terraform/` directory
  - Manual trigger via GitHub Actions UI
- **Actions**:
  - Validates Terraform syntax
  - Runs `terraform plan`
  - Automatically applies changes
  - Uploads outputs as artifacts
  - Comments outputs on the commit

### 1. Authenticate with Azure

Login to Azure using Azure CLI:
```bash
az login
```

This will open a browser window for authentication. After successful login, verify your subscription:
```bash
az account show
```

If you have multiple subscriptions, set the active one:
```bash
az account list --output table
az account set --subscription "<subscription-id-or-name>"
```

### 2. Navigate to Terraform Directory

```bash
cd terraform
```

### 3. Initialize Terraform

This downloads the required Azure provider plugins:
```bash
terraform init
```

### 4. Review the Deployment Plan

Preview what will be created/modified:
```bash
terraform plan
```

This will show you:
- Resources that will be created
- Any changes that will be made
- Output values

### 5. Deploy the Infrastructure

Apply the Terraform configuration to create the resources:
```bash
terraform apply
```

You'll be prompted to confirm. Type `yes` to proceed.

**Note**: The deployment will create:
- Resource Group: `pappu-dev-rg` (or custom name if specified)
- Virtual Network: `pappu-dev-vnet` with subnet `pappu-dev-subnet-app`
- Storage Account: `pappudevpdfsa` (sanitized name)
- Key Vault: `pappu-dev-kv`

### 6. View Outputs

After successful deployment, view the outputs:
```bash
terraform output
```

This shows important values like:
- Storage account name and blob endpoint
- Key Vault name
- Virtual network and subnet IDs

## Customization

You can customize the deployment by:

### Using Variables

Create a `terraform.tfvars` file:
```hcl
project_name = "pappu"
environment  = "dev"
location     = "westeurope"
resource_group_name = "pappu"
```

Then apply with:
```bash
terraform apply -var-file="terraform.tfvars"
```

### Override Variables via Command Line

```bash
terraform apply -var="environment=prod" -var="location=eastus"
```

## Key Vault Access

After deployment, you'll need to grant yourself access to the Key Vault (since it uses RBAC):

```bash
# Get your user object ID
USER_ID=$(az ad signed-in-user show --query id -o tsv)

# Grant Key Vault Secrets User role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $USER_ID \
  --scope $(terraform output -raw key_vault_id)
```

Or use the Azure Portal:
1. Navigate to the Key Vault
2. Go to "Access control (IAM)"
3. Click "Add" → "Add role assignment"
4. Select "Key Vault Secrets User" role
5. Assign to yourself

## Storage Account Access

The storage account is configured with:
- **Public access**: Disabled
- **Network access**: Only from the application subnet
- **HTTPS only**: Enabled

To access from your local machine, you may need to:
1. Add your IP to the network rules, OR
2. Use Azure Storage Explorer with proper authentication

## Destroying Resources

To remove all created resources:
```bash
terraform destroy
```

**Warning**: This will delete all resources created by Terraform. Make sure you have backups if needed.

## Troubleshooting

### Authentication Issues
```bash
# Re-authenticate
az login

# Verify current subscription
az account show
```

### Terraform State Issues
If you encounter state lock issues:
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Permission Errors
Ensure your Azure account has:
- **Contributor** or **Owner** role on the subscription/resource group
- Proper permissions for Key Vault (granted after creation)

## Next Steps

After infrastructure deployment:
1. Configure your application to use the storage account and Key Vault
2. Deploy your API application (see `api/` directory)
3. Monitor deployments via GitHub Actions

## Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [Terraform Documentation](https://www.terraform.io/docs)
