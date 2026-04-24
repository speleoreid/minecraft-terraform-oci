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

variable "availability_domain" {
  type        = string
  description = "Availability Domain for the compute instance"
  default     = "xIGM:PHX-AD-2"
}

variable "shape" {
  type        = string
  description = "Compute instance shape"
  default     = "VM.Standard.A1.Flex"
}
variable "shape_ocpus" {
  type        = number
  description = "Number of OCPUs for the instance shape"
  default     = 4
}
variable "shape_memory_in_gbs" {
  type        = number
  description = "Amount of memory in GBs for the instance shape"
  default     = 24
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
variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.0.0/24"
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
  default     = ["71.56.204.254/32"]
}

############################
# Compute Configuration
############################
variable "os_image_id" {
  type        = string
  description = "OCID of the OS image to use for the Minecraft instance"
  default     = "ocid1.image.oc1.phx.aaaaaaaazml2pmdmqofihn3g5b7kwogxo5bbo5jxiodx3qtpvn3uvzgja2eq"
}


variable "ssh_authorized_keys" {
  type        = string
  description = "SSH public key for instance access"
  sensitive   = true
}

# Note: 50 GB is the minimum volume size supported by OCI
variable "minecraft_data_volume_size_gb" {
  type        = number
  description = "Size of the Minecraft data volume in GB"
  default     = 50
}


############################
# Budget and Budget Alerting Configuration
############################
variable "budget_monthly_usd" {
  type        = number
  description = "The monthly budget limit in USD"
  default     = 5
}

variable "budget_email_alert" {
  type        = string
  description = "Email address to receive budget alerts"
  default     = "grapnel.gill.3c@icloud.com"
}