locals {
  ip_dashed = replace(google_compute_address.ip.address, ".", "-")
  # wp-34-1-2-3.sslip.io
  wp_domain     = "wp-${local.ip_dashed}.sslip.io"
  argocd_domain = "argocd-${local.ip_dashed}.sslip.io"
}

# ---------- Par de claves SSH ----------
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/../keys/${var.name}"
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.ssh.public_key_openssh
  filename        = "${path.module}/../keys/${var.name}.pub"
  file_permission = "0644"
}

# ---------- IP estática ----------
resource "google_compute_address" "ip" {
  name   = "${var.name}-ip"
  region = var.region
}

# ---------- Firewall ----------
resource "google_compute_firewall" "web" {
  name          = "${var.name}-allow-web"
  network       = "default"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "ssh" {
  name          = "${var.name}-allow-ssh"
  network       = "default"
  source_ranges = var.ssh_source_ranges
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ---------- Disco de datos independiente (no se borra con la VM) ----------
resource "google_compute_disk" "data" {
  name = "${var.name}-data"
  type = "pd-balanced"
  zone = var.zone
  size = var.data_disk_size_gb

  lifecycle {
    prevent_destroy = false # poner a true para proteger los datos de WordPress
  }
}

# ---------- VM Spot ----------
resource "google_compute_instance" "vm" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [var.name]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.ip.address
    }
  }

  scheduling {
    provisioning_model          = "SPOT"
    preemptible                 = true
    automatic_restart           = false
    on_host_maintenance         = "TERMINATE"
    instance_termination_action = "STOP"
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${tls_private_key.ssh.public_key_openssh}"
  }

  # El disco de datos lo gestiona google_compute_attached_disk
  lifecycle {
    ignore_changes = [attached_disk]
  }
}

resource "google_compute_attached_disk" "data" {
  disk        = google_compute_disk.data.id
  instance    = google_compute_instance.vm.id
  device_name = "data"
}

# ---------- Inventario de Ansible ----------
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    ip            = google_compute_address.ip.address
    ssh_user      = var.ssh_user
    ssh_key       = abspath(local_sensitive_file.ssh_private_key.filename)
    wp_domain     = local.wp_domain
    argocd_domain = local.argocd_domain
    acme_email    = var.acme_email
    repo_url      = var.repo_url
  })
}
