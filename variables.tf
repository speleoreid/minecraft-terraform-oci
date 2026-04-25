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
