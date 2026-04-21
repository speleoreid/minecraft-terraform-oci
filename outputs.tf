############################
# Output Variables
############################

output "instance_id" {
  description = "ID of the Minecraft compute instance"
  value       = oci_core_instance.minecraft_instance.id
}

output "instance_current_public_ip" {
  description = "Current public IP of the instance"
  value       = oci_core_instance.minecraft_instance.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the instance within the VCN"
  value       = oci_core_instance.minecraft_instance.private_ip
}

output "data_volume_id" {
  description = "ID of the persistent Minecraft data volume"
  value       = oci_core_volume.minecraft_data.id
}

output "data_volume_size_gb" {
  description = "Size of the Minecraft data volume in GB"
  value       = oci_core_volume.minecraft_data.size_in_gbs
}
