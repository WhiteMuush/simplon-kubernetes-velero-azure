terraform {
  backend "http" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=5.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_kubernetes_cluster" "velero" {
  name                = var.kubernetes_name
  location            = var.location
  resource_group_name = var.ressource_group
  dns_prefix          = var.dns_prefix

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = var.kubernetes_vm_size
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Develop"
  }
}