# ------------------------------------------------------------------------------
# Outputs for the AWS Backup Policy Module
# ------------------------------------------------------------------------------

output "backup_plan_arn" {
  description = "The ARN of the created AWS Backup Plan."
  value       = aws_backup_plan.main.arn
}
