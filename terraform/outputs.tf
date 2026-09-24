output "ip" {
  value = google_compute_address.ip.address
}

output "wordpress_url" {
  value = "https://${local.wp_domain}"
}

output "argocd_url" {
  value = "https://${local.argocd_domain}"
}

output "ssh_command" {
  value = "ssh -i ${abspath(local_sensitive_file.ssh_private_key.filename)} ${var.ssh_user}@${google_compute_address.ip.address}"
}
