CLUSTER := simplon-nginx
NODE    := $(CLUSTER)-control-plane
CONFIG  := kind-config.yaml

APP_NS     := velero-lab
MINIO_NS   := minio
BACKUP     := nginx-backup
CHART_VER  := 5.4.0
AWS_PLUGIN := velero/velero-plugin-for-aws:v1.14.2
S3_URL     := http://minio.$(MINIO_NS).svc:9000

.PHONY: create destroy start stop status help deployment service app \
        minio console velero backup restore drop check

## create: build the cluster from kind-config.yaml (first time)
create:
	kind create cluster --config $(CONFIG)

## destroy: delete the cluster completely
destroy:
	kind delete cluster --name $(CLUSTER)

## start: power on an existing (stopped) cluster
start:
	docker start $(NODE)
	@echo "waiting for API server..."
	@until kubectl get nodes >/dev/null 2>&1; do sleep 2; done
	@kubectl wait --for=condition=Ready node --all --timeout=90s

## stop: power off the cluster without deleting it
stop:
	docker stop $(NODE)

## deployment: apply the Deployment manifest
deployment:
	kubectl apply -f deployment.yaml

## service: apply the Service manifest
service:
	kubectl apply -f service.yaml

## app: deploy the demo application (Deployment + Service)
app: deployment service

## minio: install MinIO, root credentials read from .env
minio:
	@test -f .env || { echo ".env is missing, copy .env.example first"; exit 1; }
	kubectl create ns $(MINIO_NS)
	kubectl create secret generic minio-root-credentials -n $(MINIO_NS) --from-env-file=.env
	helm repo add minio https://charts.min.io/
	helm install minio minio/minio -n $(MINIO_NS) -f minio/values.yaml --version $(CHART_VER)

## console: open the MinIO console on http://127.0.0.1:9001
console:
	kubectl port-forward svc/minio-console -n $(MINIO_NS) 9001:9001

## velero: install the Velero server, needs the bucket and access key first
velero:
	@test -f .credentials-velero || { echo ".credentials-velero is missing"; exit 1; }
	velero install \
	  --provider aws \
	  --plugins $(AWS_PLUGIN) \
	  --bucket velero \
	  --secret-file ./.credentials-velero \
	  --use-volume-snapshots=false \
	  --use-node-agent=false \
	  --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=$(S3_URL)

## check: the backup location must be Available before any backup
check:
	velero backup-location get

## backup: back up the application namespace
backup:
	velero backup create $(BACKUP) --include-namespaces $(APP_NS) --wait

## drop: delete the application namespace, to test the restore
drop:
	kubectl delete namespace $(APP_NS)

## restore: bring the namespace back from the backup
restore:
	velero restore create --from-backup $(BACKUP) --wait
	kubectl get all -n $(APP_NS)

## status: show cluster and node state
status:
	@kind get clusters
	@docker ps -a --filter name=$(CLUSTER) --format 'table {{.Names}}\t{{.Status}}'

## help: list available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'
