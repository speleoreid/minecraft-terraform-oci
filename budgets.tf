############################
# OCI Budget Configuration
############################

resource "oci_budget_budget" "minecraft_budget" {
  compartment_id = var.tenancy_ocid
  amount         = var.budget_monthly_usd
  reset_period   = "MONTHLY"
  display_name   = "Minecraft-Server-Budget"
  description    = "Monthly budget for Minecraft server infrastructure"

  # Scope to just the Minecraft compartment
  targets = [var.compartment_ocid]
}

resource "oci_budget_alert_rule" "minecraft_alert_50_percent" {
  budget_id       = oci_budget_budget.minecraft_budget.id
  display_name    = "55pct-spending-alert"
  description     = "Alert when spending reaches 55% of budget"
  threshold       = 55
  threshold_type  = "PERCENTAGE"
  type            = "FORECAST"  # FORECAST = projected spending, ACTUAL = current spending
  recipients      = var.budget_email_alert
}


resource "oci_budget_alert_rule" "minecraft_alert_90_percent" {
  budget_id       = oci_budget_budget.minecraft_budget.id
  display_name    = "90pct-spending-alert"
  description     = "Critical alert when spending reaches 90% of budget"
  threshold       = 90
  threshold_type  = "PERCENTAGE"
  type            = "FORECAST"
  recipients      = var.budget_email_alert
}

resource "oci_budget_alert_rule" "minecraft_alert_100_percent" {
  budget_id       = oci_budget_budget.minecraft_budget.id
  display_name    = "100pct-spending-alert"
  description     = "Critical alert when spending reaches 100% of budget"
  threshold       = 100
  threshold_type  = "PERCENTAGE"
  type            = "FORECAST"
  recipients      = var.budget_email_alert
}
