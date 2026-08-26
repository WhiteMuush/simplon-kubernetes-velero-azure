variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  default     = "5e683e0f-b00c-48d6-9769-5aaf598de8f1"
}

variable "ressource_group" {
  description = "Ressource Group Azure."
  type        = string
  default     = "mpetitRG"
}

variable "location" {
  description = "Default location for all ressources."
  type        = string
  default     = "France Central"
}

variable "dns_prefix" {
  description = "Kubernetes DNS prefix."
  type        = string
  default     = "velero"
}

## Kubernetes Variables

variable "kubernetes_name" {
  description = "AKS name."
  type        = string
  default     = "aks-velero"
}

variable "kubernetes_vm_size" {
  description = "AKS vm size."
  type        = string
  default     = "Standard_D2_v3"
}

## Storage account + container variables

variable "git_commit" {
  description = "Short SHA of the commit that produced this infrastructure."
  type        = string
  default     = "unknown"
}

locals {
  common_tags = {
    Environment = "Develop"
    ManagedBy   = "terraform"
    GitCommit   = var.git_commit
    TfState     = "aks-velero"
  }
}

variable "storage_account_name" {
  description = "Storage Account name"
  type        = string
  default     = "mpaccountstorage"
}

variable "storage_container_name" {
  description = "Storage Container name"
  type        = string
  default     = "storagevelerocontainer"
}
## Velero identity variables

variable "velero_identity_name" {
  description = "Name of the managed identity used by Velero."
  type        = string
  default     = "id-velero"
}
