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