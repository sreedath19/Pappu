terraform {
  backend "azurerm" {
    resource_group_name  = "pappu-terraform-state-rg"
    storage_account_name = "papputerraformstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
