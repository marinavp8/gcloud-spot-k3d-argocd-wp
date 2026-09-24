# WordPress en k3d sobre VM Spot (GCP, Iowa) con ArgoCD + cert-manager

- **Terraform** crea la infraestructura en GCP y genera el inventario de Ansible.
- **Ansible** instala Docker, k3d (k3s), ArgoCD y cert-manager, y registra WordPress como Application de ArgoCD.
- **ArgoCD** despliega WordPress + MariaDB desde `k8s/wordpress` de este repo (GitOps).

## Prompt original

```
terraform:
1. crear una maquina spot en iowa
2. 8gb 4vps 40gb disco detached
3. una ip y una pareja de claves.
4. dominio sslip.io con wp-<ip>.sslip.ip.

ansible:
1. instalar k8s, k3d
2. dentro instalar argocd
3. instalar cert-manager con letsencript con jviejo@gmail.com
4. instalar wp dentro de k8s.

git:
1. hacer un git con .gitignore.
2. hacer commit con marinavp8
3. no usar claude para hacer commit.
4. usar gh para subir el repo a marinavp8 public.
```

| Requisito | Implementación |
|---|---|
| Spot en Iowa | `us-central1-a`, `provisioning_model = SPOT`; si GCP la reclama → `STOP` (no se borra) |
| 8 GB / 4 vCPU | `e2-custom-4-8192` |
| 40 GB disco detached | `google_compute_disk` independiente + `google_compute_attached_disk`, montado en `/mnt/data` |
| IP + claves | `google_compute_address` estática; `tls_private_key` ED25519 → `keys/k3d-wp` (0600) |
| Dominio | `wp-<ip-con-guiones>.sslip.io` (`sslip.ip` se tomó como errata de `sslip.io`). Extra: `argocd-<ip>.sslip.io` para la UI de ArgoCD |
| k8s con k3d | k3d `v5.9.0`, imagen `rancher/k3s:v1.36.4-k3s1`, 80/443 publicados por el LB de k3d hacia el Traefik de k3s |
| ArgoCD | `v3.5.3` (manifiesto oficial), `server.insecure` porque Traefik termina TLS |
| cert-manager | `v1.21.2`; `ClusterIssuer` `letsencrypt-prod` y `letsencrypt-staging`, HTTP-01 por Traefik, email `jviejo@gmail.com` |
| WordPress en k8s | `wordpress:6-apache` + `mariadb:11`, sincronizado por ArgoCD (auto-sync, prune, self-heal) |

## Estructura

```
.
├── terraform/
│   ├── versions.tf, variables.tf, main.tf, outputs.tf
│   └── templates/inventory.ini.tftpl   # → ansible/inventory.ini
├── ansible/
│   ├── ansible.cfg, site.yml
│   └── roles/
│       ├── base/          # monta el disco de datos, instala Docker
│       ├── k3d/           # kubectl + k3d + cluster "wp"
│       ├── argocd/        # ArgoCD + Ingress de la UI
│       ├── cert_manager/  # cert-manager + ClusterIssuers
│       └── wordpress/     # Secret de la BBDD + Application de ArgoCD
├── k8s/wordpress/         # kustomize que sincroniza ArgoCD
└── keys/                  # claves SSH (ignorado en git)
```

### Decisiones

- **Persistencia**: el directorio de `local-path` de k3s (`/var/lib/rancher/k3s/storage`) se monta desde `/mnt/data/k3s-storage`, así los PV de MariaDB y WordPress viven en el disco de 40 GB. Docker tiene un drop-in `RequiresMountsFor=/mnt/data` para no arrancar antes que el disco cuando la Spot se vuelve a encender.
- **Dominio dinámico**: la IP no se conoce hasta el `apply`, así que el host del Ingress no está en git; la Application de ArgoCD lo inyecta con un `kustomize.patches`.
- **Secretos**: las contraseñas de MariaDB se generan en el servidor (`openssl rand`) como Secret `wordpress-db`; ni pasan por git ni por el portátil.
- **API de Kubernetes** solo en `127.0.0.1:6443` de la VM; se usa por SSH.

## Uso

Orden: el repo ya debe estar en GitHub (ArgoCD lo clona), después Terraform y Ansible.

```bash
# 1. Infra (token temporal de la SA terraform-sa; dura ~1 h)
export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token --account terraform-sa@codecrypto-ai.iam.gserviceaccount.com)
cd terraform
terraform init
terraform apply
terraform output

# 2. Software
cd ../ansible
ansible-playbook site.yml </dev/null 2>&1 | cat   # el pipe evita el error "non-blocking IO" de Ansible en Warp
```

Operación:

```bash
$(terraform -chdir=terraform output -raw ssh_command)       # entrar
kubectl get pods -A                                           # en la VM (kubeconfig ya configurado)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d   # password admin de ArgoCD
gcloud compute instances start k3d-wp --zone us-central1-a    # si la Spot se ha parado
terraform -chdir=terraform destroy                            # borrarlo todo (incluido el disco de datos)
```

## Seguridad

- `keys/`, `*.tfstate`, `*.tfvars` y `ansible/inventory.ini` están en `.gitignore`. La clave privada SSH también está en `terraform.tfstate`: tratarlo como secreto.
- SSH abierto a `0.0.0.0/0` por defecto; restringir con `ssh_source_ranges`.
- Completar cuanto antes el asistente de WordPress (`/wp-admin/install.php`) y cambiar la contraseña inicial de ArgoCD.
