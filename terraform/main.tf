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
}

resource "azurerm_storage_account" "pdf" {
  name                     = lower(replace("${var.project_name}${var.environment}pdfsa", "/[^a-z0-9]/", ""))
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_blob_public_access      = false
  min_tls_version               = "TLS1_2"
  https_traffic_only_enabled    = true
  public_network_access_enabled = false

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }

  tags = azurerm_resource_group.this.tags
}

resource "azurerm_storage_container" "pdf_uploads" {
  name                  = "pdf-uploads"
  storage_account_name  = azurerm_storage_account.pdf.name
  container_access_type = "private"
}

resource "azurerm_key_vault" "this" {
  name                        = "${var.project_name}-${var.environment}-kv"
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  enable_rbac_authorization   = true
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



