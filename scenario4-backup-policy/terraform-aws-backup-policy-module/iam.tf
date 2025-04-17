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
