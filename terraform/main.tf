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

## AKS configuration
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

## Azure Account + container + Blob Storage configuration

resource "azurerm_storage_account" "velero" {
  name                     = var.storage_account_name
  resource_group_name      = var.ressource_group
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}

resource "azurerm_storage_container" "velero" {
  name                  = "content"
  storage_account_id    = azurerm_storage_account.velero.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "velero" {
  name                 = var.storage_blob_name
  storage_container_id = azurerm_storage_container.velero.id
  type                 = "Block"
  source               = var.storage_blob_source
}