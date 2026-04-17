variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID"
}

variable "user_ocid" {
  type        = string
  description = "OCI user OCID"
}

variable "api_fingerprint" {
  type        = string
  description = "Fingerprint of the OCI API signing key"
}

variable "private_key_path" {
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  type        = string
  default     = "us-phoenix-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID"
}

############################
# Network Configuration
############################
variable "vcn_cidr" {
  type        = string
  description = "CIDR block for VCN"
  default     = "10.0.0.0/16"
}

variable "minecraft_server_ips" {
  type = map(object({
    ip          = string
    description = string
  }))
  description = "Minecraft server IPs that need access"
  default = {
    "15808-agate" = {
      ip          = "71.56.204.254/32"
      description = "15808 Agate"
    }
    "seth-emily-rexburg" = {
      ip          = "192.225.180.2/32"
      description = "Seth and Emily in Rexburg"
    }
    "joseph-sorenson" = {
      ip          = "73.243.160.87/32"
      description = "Joseph Sorenson"
    }
  }
}

variable "ssh_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed for SSH access"
  default     = ["0.0.0.0/0"]
}

############################
# Compute Configuration
############################
variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key for instance access"
  sensitive   = true
}

variable "minecraft_data_volume_size_gb" {
  type        = number
  description = "Size of the Minecraft data volume in GB"
  default     = 50
}

variable "reserved_public_ip" {
  type        = string
  description = "Reserved public IP address for the instance"
  default     = "129.146.160.184"
}
