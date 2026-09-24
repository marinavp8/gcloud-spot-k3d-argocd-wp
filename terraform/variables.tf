variable "project_id" {
  description = "Proyecto de GCP"
  type        = string
  default     = "codecrypto-ai"
}

variable "region" {
  description = "Región (us-central1 = Iowa)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona dentro de Iowa"
  type        = string
  default     = "us-central1-a"
}

variable "name" {
  description = "Prefijo para los recursos"
  type        = string
  default     = "k3d-wp"
}

variable "machine_type" {
  description = "Tipo de máquina: 4 vCPU / 8 GB (custom E2)"
  type        = string
  default     = "e2-custom-4-8192"
}

variable "boot_disk_size_gb" {
  description = "Tamaño del disco de arranque (SO + imágenes Docker)"
  type        = number
  default     = 30
}

variable "data_disk_size_gb" {
  description = "Tamaño del disco de datos independiente (sobrevive a la VM)"
  type        = number
  default     = 40
}

variable "ssh_user" {
  description = "Usuario Linux para SSH / Ansible"
  type        = string
  default     = "jose"
}

variable "acme_email" {
  description = "Email para Let's Encrypt (cert-manager)"
  type        = string
  default     = "jviejo@gmail.com"
}

variable "repo_url" {
  description = "Repo git que ArgoCD sincroniza (manifiestos en k8s/wordpress)"
  type        = string
  default     = "https://github.com/marinavp8/gcloud-spot-k3d-argocd-wp.git"
}

variable "ssh_source_ranges" {
  description = "CIDRs que pueden entrar por SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
