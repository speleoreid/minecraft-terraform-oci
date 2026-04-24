############################
# Virtual Cloud Networks
############################
resource "oci_core_vcn" "vcn-minecraft" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = "vcn-minecraft"
  dns_label      = "projects"

  freeform_tags = {}
}

############################
# Internet Gateway
############################
resource "oci_core_internet_gateway" "igw-vcn-minecraft" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-minecraft.id
  display_name   = "Internet Gateway vcn-minecraft"
  enabled        = true

  freeform_tags = {}
}

############################
# Default Route Table
############################
resource "oci_core_default_route_table" "default_route_table" {
  manage_default_resource_id = oci_core_vcn.vcn-minecraft.default_route_table_id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw-vcn-minecraft.id
  }

  freeform_tags = {}
}

############################
# Default Security List
############################
resource "oci_core_default_security_list" "default_security_list" {
  manage_default_resource_id = oci_core_vcn.vcn-minecraft.default_security_list_id

  # Egress rule - all traffic to anywhere
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # SSH access from allowed CIDR blocks
  dynamic "ingress_security_rules" {
    for_each = var.ssh_allowed_cidrs
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # ICMP from anywhere (destination unreachable)
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    description = "Allow ICMP echo (ping)"
    icmp_options {
      type = 3
      code = 4
    }
  }

  # ICMP from VCN (destination unreachable)
  ingress_security_rules {
    protocol    = "1"
    source      = var.vcn_cidr
    icmp_options {
      type = 3
    }
  }

  # Minecraft server access (TCP)
  dynamic "ingress_security_rules" {
    for_each = var.minecraft_server_ips
    content {
      protocol    = "6"
      source      = ingress_security_rules.value.ip
      tcp_options {
        min = 25565
        max = 25565
      }
      description = ingress_security_rules.value.description
    }
  }

  # Minecraft server access (UDP)
  dynamic "ingress_security_rules" {
    for_each = var.minecraft_server_ips
    content {
      protocol    = "17"
      source      = ingress_security_rules.value.ip
      udp_options {
        min = 25565
        max = 25565
      }
      description = ingress_security_rules.value.description
    }
  }

  freeform_tags = {}
}

############################
# Subnets
############################
resource "oci_core_subnet" "minecraft_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.vcn-minecraft.id
  cidr_block        = var.subnet_cidr
  display_name      = "minecraft-subnet"
  dns_label         = "minecraftsubnet"
  #prohibit_internet_ingress  = false
  prohibit_public_ip_on_vnic = false

  freeform_tags = {}
}



