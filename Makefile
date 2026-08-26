# Azure
RESOURCE_GROUP  := mpetitRG
CLUSTER         := aks-velero
STORAGE_ACCOUNT := mpaccountstorage
CONTAINER       := storagevelerocontainer

# Kubernetes
APP_NS      := velero-lab
VELERO_NS   := velero
BACKUP      := nginx-backup

# Paths
TF_DIR   := terraform
K8S_DIR  := kubernetes
TF_ENV   := scripts/tf-env.sh
TF_PLAN  := tfplan.bin

.PHONY: help state-setup plan apply destroy kubeconfig setup-velero \
        app check backup drop restore blobs status

## help: list available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'

# Infrastructure (Terraform)

## state-setup: configure the GitLab remote state backend (prompts for the token)
state-setup:
	@. $(TF_ENV)

## plan: review the infrastructure changes, saved to tfplan.bin
plan:
	@. $(TF_ENV) && terraform -chdir=$(TF_DIR) plan -out=$(TF_PLAN)

## apply: apply the reviewed plan (run make plan first)
apply:
	@. $(TF_ENV) && terraform -chdir=$(TF_DIR) apply $(TF_PLAN)

## destroy: tear down every Azure resource
destroy:
	@. $(TF_ENV) && terraform -chdir=$(TF_DIR) destroy

# Cluster

## kubeconfig: point kubectl at the AKS cluster
kubeconfig:
	az aks get-credentials --resource-group $(RESOURCE_GROUP) --name $(CLUSTER)

## setup-velero: install Velero on the cluster with Workload Identity
setup-velero:
	@./scripts/velero-setup.sh

## app: deploy the nginx Deployment and Service
app:
	kubectl apply -f $(K8S_DIR)/

## status: cluster, application and Velero state
status:
	@kubectl get nodes
	@kubectl get all -n $(APP_NS)
	@kubectl get pods -n $(VELERO_NS)

# Backup and restore

## check: the backup location must be Available before any backup
check:
	velero backup-location get -n $(VELERO_NS)

## backup: back up the application namespace
backup:
	velero backup create $(BACKUP) --include-namespaces $(APP_NS) --wait

## drop: delete the application namespace, to test the restore
drop:
	kubectl delete namespace $(APP_NS)

## restore: bring the namespace back from the backup
restore:
	velero restore create --from-backup $(BACKUP) --wait
	@kubectl wait --for=condition=Available deployment/nginx -n $(APP_NS) --timeout=120s
	@kubectl get all -n $(APP_NS)

## blobs: list what Velero wrote into the Azure container
blobs:
	@az storage blob list \
	  --account-name $(STORAGE_ACCOUNT) \
	  --container-name $(CONTAINER) \
	  --auth-mode login \
	  --query "[].name" -o tsv
