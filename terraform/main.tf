terraform {
  backend "http" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=5.0.0"
    }
  }
}

## Configure the Microsoft Azure Provider
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

  # Both are required by Workload Identity: the issuer signs the tokens, the
  # webhook injects them into the annotated pods.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

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

## Azure Storage account + container that will hold the Velero backups

resource "azurerm_storage_account" "velero" {
  name                     = var.storage_account_name
  resource_group_name      = var.ressource_group
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}

resource "azurerm_storage_container" "velero" {
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.velero.id
  container_access_type = "private"
}

## Workload Identity, so Velero reaches the storage account without any key

resource "azurerm_user_assigned_identity" "velero" {
  name                = var.velero_identity_name
  resource_group_name = var.ressource_group
  location            = var.location
  tags                = local.common_tags
}

# Scoped to the storage account only, not to the whole subscription as the
# plugin documentation suggests.
resource "azurerm_role_assignment" "velero_storage" {
  scope                = azurerm_storage_account.velero.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}

# Trust link between the two worlds: the "velero" service account of the
# "velero" namespace, in this cluster, may act as the identity above.
resource "azurerm_federated_identity_credential" "velero" {
  name                      = "velero-federated-credential"
  user_assigned_identity_id = azurerm_user_assigned_identity.velero.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.velero.oidc_issuer_url
  subject                   = "system:serviceaccount:velero:velero"
}
