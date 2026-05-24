/* Compute Resources */

data "oci_core_images" "ubuntu_aarch64" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "server_instance" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.tenancy_ocid
  display_name        = "serverInstance"
  shape               = var.instance_shape

  shape_config {
    ocpus             = var.instance_ocpus
    memory_in_gbs     = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.server_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = false
    hostname_label   = "genserver"
  }

  source_details {
    source_type = "image"
    source_id   = var.os_image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  extended_metadata = {
    user_data = base64encode(templatefile("${path.module}/user_data.sh", {
      admin_username      = var.admin_username
      ssh_authorized_keys = file(var.ssh_public_key_path)
      certbot_domain_name = var.certbot_domain_name
      certbot_email       = var.certbot_email
    }))
  }

  lifecycle {
    ignore_changes = [extended_metadata]
  }
}

data "oci_core_vnic_attachments" "app_vnics" {
  compartment_id      = var.tenancy_ocid
  availability_domain = data.oci_identity_availability_domain.ad.name
  instance_id         = oci_core_instance.server_instance.id
}

data "oci_core_vnic" "app_vnic" {
  vnic_id = data.oci_core_vnic_attachments.app_vnics.vnic_attachments[0]["vnic_id"]
}

############################
# Get Primary Private IP
############################
data "oci_core_private_ips" "primary_private_ip" {
  vnic_id = data.oci_core_vnic.app_vnic.id
  
  filter {
    name   = "is_primary"
    values = ["true"]
  }
}

############################
# Elastic Public IP (Static)
############################
resource "oci_core_public_ip" "server_public_ip" {
  compartment_id = var.tenancy_ocid
  lifetime       = "RESERVED"
  display_name   = "minecraft-server-ip"
  private_ip_id  = data.oci_core_private_ips.primary_private_ip.private_ips[0].id
}

############################
# Data Volume (Persistent)
############################
resource "oci_core_volume" "persistent_data" {
  compartment_id      = var.tenancy_ocid
  availability_domain = oci_core_instance.server_instance.availability_domain
  display_name        = "persistent-data"
  size_in_gbs         = var.minecraft_data_volume_size_gb

  freeform_tags = {
    "purpose" = "persistent-application-data"
  }

  # Prevent accidental destruction of the data volume
  # The volume persists when the instance is recreated
  # Only the attachment is re-created to link to the new instance
  lifecycle {
    prevent_destroy = true
  }
}

############################
# Data Volume Attachment
############################
resource "oci_core_volume_attachment" "persistent_data_attach" {
  attachment_type        = "paravirtualized"
  instance_id            = oci_core_instance.server_instance.id
  volume_id              = oci_core_volume.persistent_data.id
  display_name           = "minecraft-data-attachment"
  is_pv_encryption_in_transit_enabled = false
}

