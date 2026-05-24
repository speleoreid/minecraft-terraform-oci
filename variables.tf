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
  description = "OCI API private key path"
}

variable "region" {
  type        = string
  description = "OCI region identifier"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "instance_shape" {
  type        = string
  description = "OCI compute instance shape"
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  type        = number
  description = "Number of OCPUs for the instance"
  default     = 4
}

variable "instance_shape_config_memory_in_gbs" {
  type        = number
  description = "Amount of memory in GB for the instance"
  default     = 24
}

variable "boot_volume_size_in_gbs" {
  type        = number
  description = "Size of the boot volume in GB (OCI minimum: 50)"
  default     = 50
}

variable "os_image_id" {
  type        = string
  description = "OCID of the OS image to use for the Minecraft instance"
  default     = "ocid1.image.oc1.phx.aaaaaaaa6m3airkzbr4zy6t3paptakqvluxgsqmgw45li3jfzwcbog2ginva" # "Canonical-Ubuntu-24.04-Minimal-aarch64-2026.03.31-0" - 
}

variable "minecraft_data_volume_size_gb" {
  type        = number
  description = "Size of the Minecraft data volume in GB"
  default     = 50
}

variable "admin_username" {
  type        = string
  description = "Username for admin SSH access (avoid committing to git - use terraform.tfvars)"
  sensitive   = true
}

variable "minecraft_allowed_ips" {
  type        = list(string)
  description = "List of IP addresses allowed to access Minecraft (25565). Use CIDR notation (e.g., '192.0.2.1/32' for a single IP, or '192.0.2.0/24' for a range)"
  default     = ["0.0.0.0/0"]
}

variable "certbot_domain_name" {
  type        = string
  description = "Domain name for automatic HTTPS certificate generation (e.g., minecraft.example.com). Leave empty to configure manually after deployment. Requires certbot_email to be set."
  default     = ""
}

variable "certbot_email" {
  type        = string
  description = "Email address for Let's Encrypt certificate notifications and recovery. Leave empty to configure manually after deployment. Requires certbot_domain_name to be set."
  default     = ""
  sensitive   = true
}