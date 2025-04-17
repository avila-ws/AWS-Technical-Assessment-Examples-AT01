# ------------------------------------------------------------------------------
# Outputs for the AWS Backup Policy Module
# ------------------------------------------------------------------------------

output "backup_plan_arn" {
  description = "The ARN of the created AWS Backup Plan."
  value       = aws_backup_plan.main.arn
}

output "backup_plan_id" {
  description = "The ID of the created AWS Backup Plan."
  value       = aws_backup_plan.main.id
}

output "primary_backup_vault_arn" {
  description = "The ARN of the primary AWS Backup Vault created by the module."
  value       = aws_backup_vault.primary.arn
}

output "primary_backup_vault_name" {
  description = "The Name of the primary AWS Backup Vault created by the module."
  value       = aws_backup_vault.primary.name
}

output "backup_iam_role_arn" {
  description = "The ARN of the IAM role created for AWS Backup service."
  value       = aws_iam_role.backup_role.arn
}

output "backup_iam_role_name" {
  description = "The Name of the IAM role created for AWS Backup service."
  value       = aws_iam_role.backup_role.name
}

output "cross_account_destination_vault_policy_json" {
  description = "[Conditional] JSON policy document that MUST be applied to the cross-account destination vault to allow copies from the source account. Only generated if cross-account copy is enabled."
  # Generate policy only if cross_account_copy is enabled, otherwise output null or empty string
  value       = var.enable_cross_account_copy ? data.aws_iam_policy_document.cross_account_vault_access[0].json : "Cross-account copy not enabled. No policy generated."
}

# --- Data Source to Generate the Cross-Account Vault Policy ---
# This generates the policy document only if the cross-account copy is enabled.

data "aws_iam_policy_document" "cross_account_vault_access" {
  # Use count to prevent this data source from executing if cross-account copy is disabled
  count = var.enable_cross_account_copy ? 1 : 0

  statement {
    sid    = "AllowCrossAccountBackupCopy"
    effect = "Allow"
    actions = [
      "backup:CopyIntoBackupVault"
    ]
    principals {
      type        = "AWS"
      # Allows the source account (where this module runs) to copy into the vault
      identifiers = ["arn:aws:iam::${local.source_account_id}:root"]
    }
    # The resource should be the ARN of the destination vault in the *other* account.
    # Since the policy is APPLIED to that vault, we allow it for the vault itself.
    resources = [
      var.cross_account_destination_vault_arn
    ]

    # Optional Condition: Add condition to restrict by source organization if needed
    # condition {
    #   test     = "StringEquals"
    #   variable = "aws:PrincipalOrgID"
    #   values   = ["o-yourOrgIdHere"]
    # }
  }
}
