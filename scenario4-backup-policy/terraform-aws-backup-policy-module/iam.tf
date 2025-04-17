# ------------------------------------------------------------------------------
# IAM Role and Policy Attachment for AWS Backup Service
# ------------------------------------------------------------------------------

locals {
  # Determine final role name using default if specific name is not provided
  # Using role_name_prefix from input variable (or default derived from policy_name)
  backup_role_name = coalescelist([var.backup_iam_role_name, "${var.policy_name}-backup-service-role"])[0]
}

# Data source to construct the assume role policy document
data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name               = local.backup_role_name
  description        = "IAM role allowing AWS Backup to manage backups on behalf of the user."
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
  tags = merge(var.tags, {
    Name = local.backup_role_name
  })
}

# Attach the AWS Managed Policy for AWS Backup service role
resource "aws_iam_policy_attachment" "backup_policy_attachment" {
  name       = "${local.backup_role_name}-attachment"
  roles      = [aws_iam_role.backup_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
