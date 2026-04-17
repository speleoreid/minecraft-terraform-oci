############################
# Compute Instances
############################
resource "oci_core_instance" "instance-20241129-1228" {
  compartment_id      = var.compartment_ocid
  availability_domain = "kdMp:PHX-AD-3"
  display_name        = "instance-20241129-1228"
  shape               = "VM.Standard.A1.Flex"
  
  shape_config {
    ocpus         = 4.0
    memory_in_gbs = 24.0
  }

  create_vnic_details {
    subnet_id              = oci_core_subnet.subnet-20241128-2139.id
    display_name           = "instance-20241129-1228"
    assign_public_ip       = true
    skip_source_dest_check = false
  }

  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1.phx.aaaaaaaapvljk3ysui4qii2xdfddkpmgeybzkurbjr7ijfpk7mnawdxhzxvq"
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = false
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      name          = "Vulnerability Scanning"
      desired_state = "DISABLED"
    }

    plugins_config {
      name          = "Management Agent"
      desired_state = "DISABLED"
    }

    plugins_config {
      name          = "Custom Logs Monitoring"
      desired_state = "ENABLED"
    }

    plugins_config {
      name          = "Compute RDMA GPU Monitoring"
      desired_state = "DISABLED"
    }

    plugins_config {
      name          = "Compute Instance Monitoring"
      desired_state = "ENABLED"
    }

    plugins_config {
      name          = "Compute HPC RDMA Auto-Configuration"
      desired_state = "DISABLED"
    }

    plugins_config {
      name          = "Compute HPC RDMA Authentication"
      desired_state = "DISABLED"
    }

    plugins_config {
      name          = "Cloud Guard Workload Protection"
      desired_state = "ENABLED"
    }

    plugins_config {
      name          = "Block Volume Management"
      desired_state = "DISABLED"
    }

    plugins_config {
      name          = "Bastion"
      desired_state = "DISABLED"
    }
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
  }

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = false
  }

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-29T19:29:57.060Z"
  }

  freeform_tags = {}
}

############################
# Get Instance's Primary VNIC Info
# (used to assign reserved public IP)
############################
data "oci_core_vnic_attachments" "instance_vnics" {
  compartment_id      = var.compartment_ocid
  instance_id         = oci_core_instance.instance-20241129-1228.id
}

data "oci_core_vnic" "primary_vnic" {
  vnic_id = data.oci_core_vnic_attachments.instance_vnics.vnic_attachments[0].vnic_id
}

data "oci_core_private_ips" "primary_private_ips" {
  vnic_id = data.oci_core_vnic.primary_vnic.id
}

############################
# Reserved Public IP (Static)
############################
resource "oci_core_public_ip" "minecraft_reserved_ip" {
  compartment_id = var.compartment_ocid
  display_name   = "minecraft-reserved-ip"
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.primary_private_ips.private_ips[0].id

  freeform_tags = {
    purpose = "minecraft-server"
  }

  depends_on = [
    oci_core_instance.instance-20241129-1228,
    data.oci_core_vnic.primary_vnic,
    data.oci_core_private_ips.primary_private_ips
  ]
}

############################
# Data Volume (Persistent)
############################
resource "oci_core_volume" "minecraft_data" {
  compartment_id      = var.compartment_ocid
  availability_domain = oci_core_instance.instance-20241129-1228.availability_domain
  display_name        = "minecraft-data"
  size_in_gbs         = var.minecraft_data_volume_size_gb

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
  }

  freeform_tags = {
    "purpose" = "minecraft-game-data"
  }
}

############################
# Data Volume Attachment
############################
resource "oci_core_volume_attachment" "minecraft_data_attach" {
  attachment_type        = "paravirtualized"
  instance_id            = oci_core_instance.instance-20241129-1228.id
  volume_id              = oci_core_volume.minecraft_data.id
  display_name           = "minecraft-data-attachment"
  is_pv_encryption_in_transit_enabled = false
}



