locals {
  rg_name = var.resource_group_name != "" ? var.resource_group_name : "${var.project_name}-${var.environment}-rg"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location

  tags = merge(
    var.tags,
    {
      project     = var.project_name
      environment = var.environment
    }
  )
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.project_name}-${var.environment}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.10.0.0/16"]

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_subnet" "app" {
  name                 = "${var.project_name}-${var.environment}-subnet-app"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.1.0/24"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault"]
}

resource "azurerm_subnet" "aca" {
  name                 = "${var.project_name}-${var.environment}-snet-aca"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.10.2.0/23"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_storage_account" "pdf" {
  name                     = lower(replace("${var.project_name}${var.environment}pdfsa", "/[^a-z0-9]/", ""))
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version               = "TLS1_2"
  https_traffic_only_enabled    = true
  public_network_access_enabled = false

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.app.id, azurerm_subnet.aca.id]
    ip_rules                   = ["106.222.203.170", "106.222.200.124", "106.222.202.205"]
  }

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_storage_container" "pdf_uploads" {
  name                  = "pdf-uploads"
  storage_account_id    = azurerm_storage_account.pdf.id
  container_access_type = "private"
}

resource "azurerm_key_vault" "this" {
  name                          = "${var.project_name}-${var.environment}-kv"
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  rbac_authorization_enabled    = true
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    virtual_network_subnet_ids = [
      azurerm_subnet.app.id
    ]
  }

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_container_registry" "acr" {
  name                = lower(replace("${var.project_name}${var.environment}acr", "/[^a-z0-9]/", ""))
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_container_app_environment" "this" {
  name                           = "${var.project_name}-${var.environment}-cae"
  location                       = azurerm_resource_group.this.location
  resource_group_name            = azurerm_resource_group.this.name
  infrastructure_subnet_id       = azurerm_subnet.aca.id
  internal_load_balancer_enabled = false

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_user_assigned_identity" "aca" {
  location            = azurerm_resource_group.this.location
  name                = "${var.project_name}-${var.environment}-aca-id"
  resource_group_name = azurerm_resource_group.this.name

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_container_app" "api" {
  name                         = "${var.project_name}-${var.environment}-api"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  template {
    container {
      name   = "api"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name  = "STORAGE_ACCOUNT_NAME"
        value = azurerm_storage_account.pdf.name
      }
      env {
        name  = "PDF_CONTAINER_NAME"
        value = azurerm_storage_container.pdf_uploads.name
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.aca.client_id
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_role_assignment" "aca_blob_contributor" {
  scope                = azurerm_storage_account.pdf.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.aca.principal_id
}
