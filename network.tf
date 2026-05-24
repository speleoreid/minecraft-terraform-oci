/* Network Infrastructure */

resource "oci_core_virtual_network" "family_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.tenancy_ocid
  display_name   = "family VCN"
  dns_label      = "familyvcn"
}

resource "oci_core_internet_gateway" "family_internet_gateway" {
  compartment_id = var.tenancy_ocid
  display_name   = "family Internet Gateway"
  vcn_id         = oci_core_virtual_network.family_vcn.id
}

resource "oci_core_route_table" "family_route_table" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_virtual_network.family_vcn.id
  display_name   = "familyRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.family_internet_gateway.id
  }
}

resource "oci_core_security_list" "family_security_list" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_virtual_network.family_vcn.id
  display_name   = "familySecurityList"

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "80"
      min = "80"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "443"
      min = "443"
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.minecraft_allowed_ips
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      description = "Allow Minecraft (25565/tcp)"

      tcp_options {
        max = "25565"
        min = "25565"
      }
    }
  }
}

resource "oci_core_subnet" "server_subnet" {
  cidr_block        = "10.1.20.0/24"
  display_name      = "serverSubnet"
  dns_label         = "serversubnet"
  security_list_ids = [oci_core_security_list.family_security_list.id]
  compartment_id    = var.tenancy_ocid
  vcn_id            = oci_core_virtual_network.family_vcn.id
  route_table_id    = oci_core_route_table.family_route_table.id
  dhcp_options_id   = oci_core_virtual_network.family_vcn.default_dhcp_options_id
}
