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

  # Logic to optionally include copy actions based on enable flags
  copy_actions = {
    cross_region = var.enable_cross_region_copy ? {
      destination_vault_arn = var.cross_region_destination_vault_arn
      kms_key_arn           = var.cross_region_copy_kms_key_arn # Optional KMS key for copy
      retention_days        = var.cross_region_copy_retention_days
      } : null
    cross_account = var.enable_cross_account_copy ? {
      destination_vault_arn = var.cross_account_destination_vault_arn
      kms_key_arn           = var.cross_account_copy_kms_key_arn # Optional KMS key for copy
      retention_days        = var.cross_account_copy_retention_days
      } : null
  }
}

# --- Primary Backup Vault ---

resource "aws_backup_vault" "primary" {
  name        = local.primary_vault_name
  kms_key_arn = var.primary_kms_key_arn # Encryption key for the primary vault
  tags = merge(var.tags, {
    Name = local.primary_vault_name
  })
}

# --- Primary Vault Lock Configuration (Conditional) ---

resource "aws_backup_vault_lock_configuration" "primary_lock" {
  count = var.enable_primary_vault_lock ? 1 : 0 # Only create if enabled via variable

  backup_vault_name           = aws_backup_vault.primary.name
  min_retention_days          = var.vault_lock_min_retention_days
  max_retention_days          = var.vault_lock_max_retention_days
  changeable_for_days         = var.vault_lock_changeable_for_days # Cooling-off period
}

# --- IAM Role (Defined in iam.tf) ---
# Reference the role ARN output from the iam module/file.
# Assumes iam.tf defines the role and outputs its ARN.
module "iam" {
  source            = "./iam.tf" # Placeholder if using a true submodule structure. Remove if iam.tf is in the same directory.
  role_name_prefix  = "${var.policy_name}-backup-role"
  tags              = var.tags
  backup_iam_role_name = var.backup_iam_role_name # Pass through optional custom role name
}

# --- Backup Plan ---

resource "aws_backup_plan" "main" {
  name = local.plan_name
  tags = merge(var.tags, {
    Name = local.plan_name
  })

  rule {
    rule_name         = "${local.plan_name}-primary-rule"
    target_vault_name = aws_backup_vault.primary.name # Target the primary vault created above
    schedule          = var.backup_schedule # Use the schedule expression from variables

    # Primary retention configuration
    lifecycle {
      delete_after = var.primary_retention_days # Days to keep backups in primary vault
    }

    # Cross-Region Copy Action (Dynamic block, creates if enabled)
    dynamic "copy_action" {
      # Iterate only if local.copy_actions.cross_region is not null (i.e., var.enable_cross_region_copy was true)
      for_each = local.copy_actions.cross_region != null ? { cross_region = local.copy_actions.cross_region } : {}
      content {
        destination_vault_arn = copy_action.value.destination_vault_arn # ARN of the vault in the other region
        # Configure retention for the copy
        lifecycle {
          delete_after = copy_action.value.retention_days
        }
        # Note: Terraform AWS provider currently does not support specifying KMS key ARN directly for copy_action lifecycle.
        # Encryption uses the destination vault's default or configured key.
      }
    }

    # Cross-Account Copy Action (Dynamic block, creates if enabled)
    dynamic "copy_action" {
      # Iterate only if local.copy_actions.cross_account is not null (i.e., var.enable_cross_account_copy was true)
      for_each = local.copy_actions.cross_account != null ? { cross_account = local.copy_actions.cross_account } : {}
      content {
        destination_vault_arn = copy_action.value.destination_vault_arn # ARN of the vault in the other account
        # Configure retention for the copy
        lifecycle {
          delete_after = copy_action.value.retention_days
        }
        # KMS Key Note: Same limitation as cross-region applies.
      }
    }

    # recovery_point_tags block could be added here if needed to tag backups themselves
  }

  # advanced_backup_setting block could be added here if needed (e.g., for Windows VSS)
}

# --- Backup Resource Selection ---

resource "aws_backup_selection" "tag_based" {
  name            = local.selection_name
  iam_role_arn    = local.iam_role_arn # Reference the ARN from the IAM definition
  plan_id         = aws_backup_plan.main.id

  # Define tags for selection (Resources MUST match BOTH tags)
  selection_tag {
    type  = "STRINGEQUALS" # Condition type
    key   = var.resource_selection_tag_key_1 # First tag key from variable
    value = var.resource_selection_tag_value_1 # First tag value from variable
  }

  selection_tag {
    type  = "STRINGEQUALS" # Condition type
    key   = var.resource_selection_tag_key_2 # Second tag key from variable
    value = var.resource_selection_tag_value_2 # Second tag value from variable
  }

  # 'condition' or 'resources' blocks could optionally be added here for more complex selection logic.
  # Removed 'tags' argument here as it's not supported by this resource type.
}