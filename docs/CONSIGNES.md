# Brief

## Summary

Set up a backup policy for Kubernetes resources (Services, Deployments,
ConfigMaps...) with **Velero**. Those backups can be restored after a cluster
incident, or used to migrate to another cluster.

Backups are stored in an **Azure Blob Storage** container, a service configured
with a script or with Terraform.

Every step must be documented: the documentation is the final deliverable.

## Steps

1. **Create an AKS cluster** (1h): this time Velero is set up on Azure's cloud
2. **Create the Azure Blob Storage container** (1h): the equivalent of the MinIO bucket, or of an S3 bucket. The container holds the backups
3. **Follow the guide to install Velero on the AKS cluster** (3h): access keys are tolerated for this first brief, but "Workload Identity" (OIDC) is preferred. https://github.com/velero-io/velero-plugin-for-microsoft-azure#setup
4. **Run a backup and restore procedure** (1h): same example as the previous brief, the nginx Deployment and its Service
5. **Check that files show up in the Azure Blob Storage container** (30min)

## Bonus

- The Azure Blob Storage container is reachable only from the Kubernetes cluster and from the Simplon premises
- Configure Soft-Delete on the container
- Configure data replication for the container, in a separate region
- Configure storage account encryption with your own managed key (CMK on Key Vault)
