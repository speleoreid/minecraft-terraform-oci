############################
# Virtual Cloud Networks
############################
resource "oci_core_vcn" "vcn-20241128-2139" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "vcn-20241128-2139"
  dns_label      = "vcn11282143"

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-29T04:43:11.716Z"
  }

  freeform_tags = {}
}

resource "oci_core_vcn" "vcn-20241128-1152" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "vcn-20241128-1152"
  dns_label      = "vcn11281154"

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-28T18:54:57.429Z"
  }

  freeform_tags = {}
}

############################
# Subnets
############################
resource "oci_core_subnet" "subnet-20241128-2139" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.vcn-20241128-2139.id
  cidr_block        = "10.0.0.0/24"
  display_name      = "subnet-20241128-2139"
  dns_label         = "subnet11282143"
  route_table_id    = "ocid1.routetable.oc1.phx.aaaaaaaamwc5goxbxql5bku5gfscax4ck2gliweedkvf6jbzkwfod2n4szwq"
  security_list_ids = ["ocid1.securitylist.oc1.phx.aaaaaaaas3oaa66xgjdobza3hvlm76e4h35cejq7eeigo5kpwenxz32malhq"]

  prohibit_internet_ingress  = false
  prohibit_public_ip_on_vnic = false

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-29T04:43:14.147Z"
  }

  freeform_tags = {}
}

resource "oci_core_subnet" "subnet-20241128-1152" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.vcn-20241128-1152.id
  cidr_block        = "10.0.0.0/24"
  display_name      = "subnet-20241128-1152"
  dns_label         = "subnet11281154"
  route_table_id    = "ocid1.routetable.oc1.phx.aaaaaaaatb7bfmbddxcmaihqywarghfcbawxk6bimx7uy3dnivq4sltjkzpq"
  security_list_ids = ["ocid1.securitylist.oc1.phx.aaaaaaaaey5xe2ufm2ncb64t5deb2h4ddiyt4tbtepxyqvtilrbza242asra"]

  prohibit_internet_ingress  = false
  prohibit_public_ip_on_vnic = false

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-28T18:54:59.725Z"
  }

  freeform_tags = {}
}

############################
# Route Tables
############################
resource "oci_core_route_table" "route-table-vcn-20241128-2139" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-20241128-2139.id
  display_name   = "Default Route Table for vcn-20241128-2139"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = "ocid1.internetgateway.oc1.phx.aaaaaaaa4qov2idiskmuww7xhs742gpvc4xrlwwisk5uta55s52jp5xwwvnq"
  }

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-29T04:43:11.716Z"
  }

  freeform_tags = {}
}

resource "oci_core_route_table" "route-table-vcn-20241128-1152" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-20241128-1152.id
  display_name   = "Default Route Table for vcn-20241128-1152"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = "ocid1.internetgateway.oc1.phx.aaaaaaaav2lzuhawdmfneudw6tqjntykeefyebun2nbgixbyu6rn2lf2djuq"
  }

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-28T18:54:57.429Z"
  }

  freeform_tags = {}
}

############################
# Internet Gateways
############################
resource "oci_core_internet_gateway" "igw-vcn-20241128-2139" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-20241128-2139.id
  display_name   = "Internet Gateway vcn-20241128-2139"
  enabled        = true

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-29T04:43:13.055Z"
  }

  freeform_tags = {}
}

resource "oci_core_internet_gateway" "igw-vcn-20241128-1152" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-20241128-1152.id
  display_name   = "Internet Gateway vcn-20241128-1152"
  enabled        = true

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-28T18:54:58.679Z"
  }

  freeform_tags = {}
}

############################
# DHCP Options
############################
resource "oci_core_dhcp_options" "dhcp-options-vcn-20241128-2139" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-20241128-2139.id
  display_name   = "Default DHCP Options for vcn-20241128-2139"

  options {
    type                = "DomainNameServer"
    server_type         = "VcnLocalPlusInternet"
    custom_dns_servers  = []
  }

  options {
    type                  = "SearchDomain"
    search_domain_names   = ["vcn11282143.oraclevcn.com"]
  }

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-29T04:43:11.716Z"
  }

  freeform_tags = {}
}

resource "oci_core_dhcp_options" "dhcp-options-vcn-20241128-1152" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-20241128-1152.id
  display_name   = "Default DHCP Options for vcn-20241128-1152"

  options {
    type                = "DomainNameServer"
    server_type         = "VcnLocalPlusInternet"
    custom_dns_servers  = []
  }

  options {
    type                  = "SearchDomain"
    search_domain_names   = ["vcn11281154.oraclevcn.com"]
  }

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-28T18:54:57.429Z"
  }

  freeform_tags = {}
}

############################
# Security Lists
############################
resource "oci_core_security_list" "security-list-vcn-20241128-2139" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-20241128-2139.id
  display_name   = "Default Security List for vcn-20241128-2139"

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
      source      = "71.56.204.254/32"
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

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-29T04:43:11.716Z"
  }

  freeform_tags = {}
}

resource "oci_core_security_list" "security-list-vcn-20241128-1152" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn-20241128-1152.id
  display_name   = "Default Security List for vcn-20241128-1152"

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
      source      = "0.0.0.0/0"
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

  # Minecraft TCP from anywhere
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 25565
      max = 25565
    }
  }

  # Minecraft UDP from anywhere
  ingress_security_rules {
    protocol    = "17"
    source      = "0.0.0.0/0"
    udp_options {
      min = 25565
      max = 25565
    }
  }

  defined_tags = {
    "Oracle-Tags.CreatedBy" = "default/gusset-airway0x@icloud.com"
    "Oracle-Tags.CreatedOn" = "2024-11-28T18:54:57.429Z"
  }

  freeform_tags = {}
}

