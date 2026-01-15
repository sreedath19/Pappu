variable "project_name" {
  description = "Short name for this project, used in resource naming."
  type        = string
  default     = "asbitech"
}

variable "environment" {
  description = "Environment name (e.g. dev, stage, prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Optional explicit resource group name. If empty, one will be generated."
  type        = string
  default     = "asbitech"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    owner       = "data-engineering"
    managed_by  = "terraform"
  }
}

