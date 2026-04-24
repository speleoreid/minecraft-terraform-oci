############################
# Compute Instances
############################
resource "oci_core_instance" "minecraft_instance" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "minecraft-instance"
  shape               = var.shape

  shape_config {
    ocpus         = var.shape_ocpus
    memory_in_gbs = var.shape_memory_in_gbs
  }

  create_vnic_details {
    subnet_id              = oci_core_subnet.minecraft_subnet.id
    display_name           = "minecraft-instance"
    hostname_label         = "minecraft-instance"
    assign_public_ip       = true
    skip_source_dest_check = false
  }

  source_details {
    source_type = "image"
    source_id   = var.os_image_id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
    user_data           = base64encode(templatefile("${path.module}/user_data.sh", {
      ssh_authorized_keys = var.ssh_authorized_keys
    }))
  }

  freeform_tags = {
    purpose = "minecraft-server"
  }

  depends_on = [
    oci_core_internet_gateway.igw-vcn-minecraft,
    oci_core_default_route_table.default_route_table,
    oci_core_default_security_list.default_security_list
  ]
}

############################
# Data Volume (Persistent)
############################
resource "oci_core_volume" "minecraft_data" {
  compartment_id      = var.compartment_ocid
  availability_domain = oci_core_instance.minecraft_instance.availability_domain
  display_name        = "minecraft-data"
  size_in_gbs         = var.minecraft_data_volume_size_gb

  freeform_tags = {
    "purpose" = "minecraft-game-data"
  }
}

############################
# Data Volume Attachment
############################
resource "oci_core_volume_attachment" "minecraft_data_attach" {
  attachment_type        = "paravirtualized"
  instance_id            = oci_core_instance.minecraft_instance.id
  volume_id              = oci_core_volume.minecraft_data.id
  display_name           = "minecraft-data-attachment"
  is_pv_encryption_in_transit_enabled = false
}



