# ******************************************************************************************************
#  PROVIDER Terraform file  /                     v1.0         /                   by Daniel M.
# ******************************************************************************************************

# ------------------------------------------------------------------------  declare provider(s) 
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.51.0"
    }
  }
}

# ------------------------------------------------------------------------  use appId to get access to Azure 
provider "azurerm" {
  subscription_id = "8d647fc2-6870-4fb0-b792-7e922d176550"
  client_id       = "44f38ec4-6c7f-41cf-a696-eaed7e50694d"
  # client_secret   = var.client_secret
  client_secret = "nJG8Q~ooTJiH~KnYJ5JPWH3QRnjv7p2~KhYhraQ7"
  tenant_id     = "0b3fc178-b730-4e8b-9843-e81259237b77"
  features {}
}

# ------------------------------------------------------------------------
