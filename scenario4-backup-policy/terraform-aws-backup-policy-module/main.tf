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

# --- IAM Role (Defined in iam.tf) ---
# We refer to the role ARN output from the iam module/file
module "iam" {
  source            = "./iam.tf" # Placeholder if using a true submodule structure
                                # If iam.tf is in the same dir, direct reference via local.iam_role_arn suffices
  role_name_prefix  = "${var.policy_name}-backup-role"
  tags              = var.tags
  backup_iam_role_name = var.backup_iam_role_name # Pass through optional name
}

# --- Backup Plan ---

resource "aws_backup_plan" "main" {
  name = local.plan_name
  tags = merge(var.tags, {
    Name = local.plan_name
  })

  rule {
    rule_name         = "${local.plan_name}-primary-rule"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = var.backup_schedule

    # Primary retention
    lifecycle {
      delete_after = var.primary_retention_days
    }

    # Cross-Region Copy Action (Dynamic)
    dynamic "copy_action" {
      for_each = local.copy_actions.cross_region != null ? { cross_region = local.copy_actions.cross_region } : {}
      content {
        destination_vault_arn = copy_action.value.destination_vault_arn
        lifecycle {
          delete_after = copy_action.value.retention_days
        }
        # Note: Terraform AWS provider does not currently support specifying KMS key for copy_action lifecycle.
        # It will use the destination vault's default or configured key implicitly.
        # If a specific key is needed, ensure the *destination vault* is configured with it.
      }
    }

    # Cross-Account Copy Action (Dynamic)
    dynamic "copy_action" {
      for_each = local.copy_actions.cross_account != null ? { cross_account = local.copy_actions.cross_account } : {}
      content {
        destination_vault_arn = copy_action.value.destination_vault_arn
        lifecycle {
          delete_after = copy_action.value.retention_days
        }
        # Same KMS note as above applies here.
      }
    }

    # recovery_point_tags could be added here if needed
  }

  # advanced_backup_setting could be added here (e.g., for specific resource types like Windows VSS)
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