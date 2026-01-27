output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Name of the resource group."
}

output "location" {
  value       = azurerm_resource_group.this.location
  description = "Azure region for the resources."
}

output "storage_account_name" {
  value       = azurerm_storage_account.pdf.name
  description = "Name of the storage account used for PDF uploads."
}

output "storage_account_blob_endpoint" {
  value       = azurerm_storage_account.pdf.primary_blob_endpoint
  description = "Blob endpoint for the storage account."
}

output "pdf_container_name" {
  value       = azurerm_storage_container.pdf_uploads.name
  description = "Blob container name for PDF uploads."
}

output "virtual_network_id" {
  value       = azurerm_virtual_network.this.id
  description = "ID of the virtual network."
}

output "app_subnet_id" {
  value       = azurerm_subnet.app.id
  description = "ID of the application subnet."
}

output "key_vault_name" {
  value       = azurerm_key_vault.this.name
  description = "Name of the Key Vault."
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "Login server for the Azure Container Registry."
}

output "container_app_fqdn" {
  value       = azurerm_container_app.api.latest_revision_fqdn
  description = "FQDN of the Container App."
}
