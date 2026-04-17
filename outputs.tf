############################
# Output Variables
############################

output "instance_id" {
  description = "ID of the Minecraft compute instance"
  value       = oci_core_instance.instance-20241129-1228.id
}

output "instance_current_public_ip" {
  description = "Current public IP of the instance (may be ephemeral)"
  value       = oci_core_instance.instance-20241129-1228.public_ip
}

output "reserved_public_ip" {
  description = "Reserved public IP address for future rebuilds"
  value       = oci_core_public_ip.minecraft_reserved_ip.ip_address
}

output "reserved_public_ip_id" {
  description = "OCI ID of the reserved public IP"
  value       = oci_core_public_ip.minecraft_reserved_ip.id
}

output "instance_private_ip" {
  description = "Private IP of the instance within the VCN"
  value       = oci_core_instance.instance-20241129-1228.private_ip
}

output "data_volume_id" {
  description = "ID of the persistent Minecraft data volume"
  value       = oci_core_volume.minecraft_data.id
}

output "data_volume_size_gb" {
  description = "Size of the Minecraft data volume in GB"
  value       = oci_core_volume.minecraft_data.size_in_gbs
}
