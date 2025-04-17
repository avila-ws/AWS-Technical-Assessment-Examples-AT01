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
