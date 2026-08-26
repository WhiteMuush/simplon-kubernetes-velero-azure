output "cluster_name" {
  description = "AKS cluster name, used by az aks get-credentials."
  value       = azurerm_kubernetes_cluster.velero.name
}

output "resource_group" {
  description = "Resource group of the cluster, used by az aks get-credentials."
  value       = azurerm_kubernetes_cluster.velero.resource_group_name
}

output "oidc_issuer_url" {
  description = "Cluster OIDC issuer, trusted by the Velero federated identity credential."
  value       = azurerm_kubernetes_cluster.velero.oidc_issuer_url
}

output "kube_config_raw" {
  description = "Full kubeconfig, alternative to az aks get-credentials."
  value       = azurerm_kubernetes_cluster.velero.kube_config_raw
  sensitive   = true
}

output "velero_identity_client_id" {
  description = "Client ID of the Velero managed identity, set as the service account annotation."
  value       = azurerm_user_assigned_identity.velero.client_id
}
