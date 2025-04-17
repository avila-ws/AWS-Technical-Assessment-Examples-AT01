# ------------------------------------------------------------------------------
# IAM Role and Policy Attachment for AWS Backup Service
# ------------------------------------------------------------------------------

locals {
  backup_role_name = coalescelist([var.backup_iam_role_name, "${var.policy_name}-backup-service-role"])[0]
}

data "aws_iam_policy_document" "backup_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup_role" {
  name               = local.backup_role_name
  description        = "IAM role allowing AWS Backup to manage backups on behalf of the user."
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role.json
  tags = merge(var.tags, {
    Name = local.backup_role_name
  })
}

resource "aws_iam_policy_attachment" "backup_policy_attachment" {
  name       = "${local.backup_role_name}-attachment"
  roles      = [aws_iam_role.backup_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
