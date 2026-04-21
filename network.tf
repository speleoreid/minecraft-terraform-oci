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
# Subnets
############################
resource "oci_core_subnet" "subnet-private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-minecraft.id
  cidr_block     = "10.0.1.0/24"
  display_name   = "private-subnet-minecraft"
  dns_label      = "private"
  prohibit_internet_ingress  = false
  prohibit_public_ip_on_vnic = false

  freeform_tags = {}
}

############################
# Internet Gateways
############################
resource "oci_core_internet_gateway" "igw-vcn-minecraft" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-minecraft.id
  display_name   = "Internet Gateway vcn-minecraft"
  is_enabled     = true

  freeform_tags = {}
}

############################
# Route Tables
############################
resource "oci_core_route_table" "route-table-private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-minecraft.id
  display_name   = "Private Route Table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw-vcn-minecraft.id
  }

  freeform_tags = {}
}

############################
# Route Table Attachment
############################
resource "oci_core_route_table_attachment" "route-table-attachment" {
  subnet_id      = oci_core_subnet.subnet-private.id
  route_table_id = oci_core_route_table.route-table-private.id
}

############################
# DHCP Options
############################
resource "oci_core_dhcp_options" "dhcp-options-vcn-minecraft" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-minecraft.id
  display_name   = "Default DHCP Options for vcn-minecraft"

  options {
    type                = "DomainNameServer"
    server_type         = "VcnLocalPlusInternet"
    custom_dns_servers  = []
  }

  freeform_tags = {}
}

############################
# Security Lists
############################
resource "oci_core_security_list" "security-list-vcn-minecraft" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-minecraft.id
  display_name   = "Default Security List for vcn-minecraft"

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
# Security List Association
############################
resource "oci_core_security_list_association" "security-list-association" {
  security_list_id = oci_core_security_list.security-list-vcn-minecraft.id
  subnet_id        = oci_core_subnet.subnet-private.id
}

