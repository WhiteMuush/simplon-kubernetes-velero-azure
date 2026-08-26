CLUSTER := simplon-nginx
NODE    := $(CLUSTER)-control-plane
CONFIG  := kind-config.yaml

APP_NS     := velero-lab
MINIO_NS   := minio
BACKUP     := nginx-backup
CHART_VER  := 5.4.0
AWS_PLUGIN := velero/velero-plugin-for-aws:v1.14.2
S3_URL     := http://minio.$(MINIO_NS).svc:9000

.PHONY: state-setup

## state-setup: configure the GitLab remote state backend (prompts for the token)
state-setup:
	@. scripts/tf-env.sh

## help: list available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'
