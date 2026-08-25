# <img src="https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/kubernetes.svg" alt="Kubernetes" width="30" height="30" style="vertical-align:middle; filter: invert(34%) sepia(85%) saturate(3627%) hue-rotate(211deg) brightness(97%) contrast(91%);" /> Kubernetes/KIND & Velero <img src="https://cdn.jsdelivr.net/npm/simple-icons@v13/icons/minio.svg" alt="MinIO" width="30" height="30" style="vertical-align:middle; filter: invert(27%) sepia(51%) saturate(2878%) hue-rotate(346deg) brightness(94%) contrast(97%);" />

Local Kubernetes lab: back up and restore cluster resources with **Velero**,
storing the backups in **MinIO** deployed inside the **KIND** cluster.

Full brief: [`docs/CONSIGNES.md`](docs/CONSIGNES.md).

## Requirements

- Docker (running)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [KIND](https://kind.sigs.k8s.io/)
- [Helm](https://helm.sh/)
- [Velero CLI](https://github.com/vmware-tanzu/velero/releases) v1.18.2

## Credentials

Never committed. Copy the examples and fill in the real values:

```bash
cp .env.example .env                              # MinIO root user
cp .credentials-velero.example .credentials-velero # MinIO access key for Velero
```

## Quickstart

```bash
make create     # KIND cluster
make app        # nginx Deployment + Service, namespace velero-lab
make minio      # MinIO, root credentials read from .env

make console    # http://127.0.0.1:9001
                # create the "velero" bucket and an access key,
                # then write both values into .credentials-velero

make velero     # Velero server, AWS plugin pointed at the MinIO Service
make check      # backup location must be Available before going further
```

## Backup and restore

```bash
make backup     # back up the velero-lab namespace
make drop       # delete it
make restore    # bring it back from the backup
```

## Cluster management

```bash
make help       # list every shortcut
make status     # clusters and node state
make stop       # power off without deleting
make start      # power back on
make destroy    # delete the cluster
```

## Structure

```
.
├── kind-config.yaml               # cluster definition (1 node, port 8080 -> 30080)
├── deployment.yaml                # nginx Deployment (3 replicas, ns velero-lab)
├── service.yaml                   # nginx Service (NodePort 30080)
├── minio/values.yaml              # MinIO Helm values (no credentials inside)
├── .env.example                   # MinIO root credentials template
├── .credentials-velero.example    # Velero access key template
└── docs/
    └── CONSIGNES.md               # project brief + diagrams
```

## Documentation

**Velero**

- [How Velero works](https://velero.io/docs/v1.18/how-velero-works/)
- [MinIO setup guide](https://velero.io/docs/v1.18/contributions/minio/): the guide followed here, note it runs MinIO in the `velero` namespace, hence a different `s3Url`
- [Backup reference](https://velero.io/docs/v1.18/backup-reference/): `--include-namespaces` vs `--selector`
- [Restore reference](https://velero.io/docs/v1.18/restore-reference/)
- [BackupStorageLocation](https://velero.io/docs/v1.18/api-types/backupstoragelocation/): turns `Unavailable` when the credentials are wrong
- [AWS plugin](https://github.com/vmware-tanzu/velero-plugin-for-aws): plugin/Velero compatibility matrix

**MinIO**

- [Helm chart values](https://github.com/minio/minio/tree/master/helm/minio): `existingSecret`, `persistence`, `mode`
- [Access key management](https://min.io/docs/minio/kubernetes/upstream/administration/identity-access-management/minio-user-management.html)

**Kubernetes and tooling**

- [KIND configuration](https://kind.sigs.k8s.io/docs/user/configuration/): `extraPortMappings`
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/): base64 encoded, not encrypted
- [Service type NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport)
- [helm install](https://helm.sh/docs/helm/helm_install/): `-f` and `--version`

## Result

Namespace deleted, then rebuilt from the backup: the 3 pods, the Service and
the Deployment are back.

![Restoring the velero-lab namespace with Velero](docs/screenshots/restore.png)
