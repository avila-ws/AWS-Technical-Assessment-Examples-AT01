# ------------------------------------------------------------------------------
# Main Resources for the AWS Backup Policy Module
# ------------------------------------------------------------------------------

# --- Data Sources ---

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Determine final names using defaults if specific names are not provided
  primary_vault_name = coalescelist([var.primary_vault_name, "${var.policy_name}-primary-vault-${data.aws_region.current.name}"])[0]
  plan_name          = "${var.policy_name}-backup-plan"
  selection_name     = "${var.policy_name}-resource-selection"
  iam_role_arn       = module.iam.backup_role_arn # Get ARN from the IAM module part

  # Use account ID from variable, fallback to data source
  source_account_id = coalesce(var.source_account_id, data.aws_caller_identity.current.account_id)

  # Logic to optionally include copy actions
  copy_actions = {
    cross_region = var.enable_cross_region_copy ? {
      destination_vault_arn = var.cross_region_destination_vault_arn
      kms_key_arn           = var.cross_region_copy_kms_key_arn
      retention_days        = var.cross_region_copy_retention_days
      } : null
    cross_account = var.enable_cross_account_copy ? {
      destination_vault_arn = var.cross_account_destination_vault_arn
      kms_key_arn           = var.cross_account_copy_kms_key_arn
      retention_days        = var.cross_account_copy_retention_days
      } : null
  }
}

# --- Primary Backup Vault ---

resource "aws_backup_vault" "primary" {
  name        = local.primary_vault_name
  kms_key_arn = var.primary_kms_key_arn
  tags = merge(var.tags, {
    Name = local.primary_vault_name
  })
}

# --- Primary Vault Lock Configuration (Conditional) ---

resource "aws_backup_vault_lock_configuration" "primary_lock" {
  count = var.enable_primary_vault_lock ? 1 : 0

  backup_vault_name           = aws_backup_vault.primary.name
  min_retention_days          = var.vault_lock_min_retention_days
  max_retention_days          = var.vault_lock_max_retention_days
  changeable_for_days         = var.vault_lock_changeable_for_days
}

# ---