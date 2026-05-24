// Copyright (c) 2017, 2024, Oracle and/or its affiliates. All rights reserved.
// Licensed under the Mozilla Public License v2.0

/* Data Sources */

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

output "instance0_public_ip" {
  value       = oci_core_public_ip.server_public_ip.ip_address
  description = "Static public IP of instance for SSH access (persists across instance updates)"
}

output "instance0_ssh_command" {
  value       = "ssh ${var.admin_username}@${oci_core_public_ip.server_public_ip.ip_address}"
  description = "SSH command for instance"
  sensitive   = true
}

output "available_ubuntu_images" {
  value = [
    for img in data.oci_core_images.ubuntu_aarch64.images : {
      id           = img.id
      display_name = img.display_name
      time_created = img.time_created
    }
    if !strcontains(lower(img.display_name), "minimal") && strcontains(lower(img.display_name), "aarch64")
  ]
  description = "Available Ubuntu aarch64 images (newest first, excluding Minimal images)"
}

# Local resource to capture deployment timestamp in local timezone
resource "null_resource" "deployment_timestamp" {
  provisioner "local-exec" {
    command = "echo '═══════════════════════════════════════' && echo 'Deployment completed at:' && date && echo '═══════════════════════════════════════'"
  }
}



