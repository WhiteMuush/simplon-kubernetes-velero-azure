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
  default     = "Standard_B2s"
}