# Terraform AWS Backup Policy Module

## Overview

This Terraform module creates and configures a comprehensive AWS Backup policy within a single AWS account, including:

*   An AWS Backup Vault (primary storage for backups).
*   An optional Vault Lock configuration (WORM protection) on the primary vault.
*   An IAM Role for the AWS Backup service.
*   An AWS Backup Plan with a primary backup rule defining schedule, retention, and encryption.
*   Optional copy actions within the plan to copy backups to:
    *   A destination vault in a different region (within the same account).
    *   A destination vault in a different AWS account.
*   An AWS Backup Selection resource to assign resources to the plan based on specified tags.

This module is designed based on the requirements outlined in a specific technical assessment scenario but can be adapted for general use.

## Prerequisites

Before using this module, ensure the following resources exist and their ARNs are available:

1.  **Primary KMS Key:** An existing AWS KMS key in the *same region* where the module will be deployed (primary region). This key is mandatory for encrypting backups in the primary vault. (`var.primary_kms_key_arn`)
2.  **Cross-Region Destination Vault (Optional):** If enabling cross-region copies (`var.enable_cross_region_copy = true`), an existing AWS Backup Vault must exist in the desired destination region within the same AWS account. You need its ARN (`var.cross_region_destination_vault_arn`).
3.  **Cross-Account Destination Vault (Optional):** If enabling cross-account copies (`var.enable_cross_account_copy = true`), an existing AWS Backup Vault must exist in the destination AWS account and region. You need its ARN (`var.cross_account_destination_vault_arn`).
4.  **(Optional) Cross-Region KMS Key:** If you want to encrypt cross-region copies with a *specific* KMS key (other than the AWS default Backup key in that region), this key must exist in the destination region. Provide its ARN (`var.cross_region_copy_kms_key_arn`).
5.  **(Optional) Cross-Account KMS Key:** If you want to encrypt cross-account copies with a *specific* KMS key (other than the AWS default Backup key in that account/region), this key must exist in the destination account/region. Provide its ARN (`var.cross_account_copy_kms_key_arn`).

**Important Note on Cross-Account Setup:** For cross-account copies to succeed, the **destination vault** in the target account MUST have a Vault Access Policy allowing the source account (where this module is deployed) to perform the `backup:CopyIntoBackupVault` action. This module generates the necessary policy JSON as an output (`cross_account_destination_vault_policy_json`). This policy **must be applied manually** or via separate automation to the destination vault in the target account.

## Usage Example

```terraform
# Example main.tf calling the module

provider "aws" {
  region = "eu-central-1" # Frankfurt - Primary Region Example
}

# Data source to get the current account ID easily
data "aws_caller_identity" "current" {}

module "prod_backup_policy" {
  source = "./terraform-aws-backup-policy-module" # Path to the module directory

  policy_name          = "prod-critical-backups"
  backup_schedule      = "cron(0 2 ? * MON-FRI *)" # Mon-Fri at 2 AM UTC
  primary_retention_days = 90
  primary_kms_key_arn  = "arn:aws:kms:eu-central-1:111122223333:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" # Replace with actual primary KMS Key ARN

  # Resource selection tags (Resources must have BOTH)
  resource_selection_tag_key_1   = "Environment"
  resource_selection_tag_value_1 = "Production"
  resource_selection_tag_key_2   = "BackupTier"
  resource_selection_tag_value_2 = "Critical"

  # Enable Vault Lock on primary vault
  enable_primary_vault_lock      = true
  vault_lock_min_retention_days  = 30
  vault_lock_max_retention_days  = 365 * 7 # 7 years
  vault_lock_changeable_for_days = 7 # 1 week cooling-off

  # Cross-Region Copy Config (Example: Frankfurt to Ireland)
  enable_cross_region_copy           = true
  cross_region_destination_vault_arn = "arn:aws:backup:eu-west-1:111122223333:backup-vault:prod-frankfurt-copy-vault-ireland" # Replace with actual Dest Vault ARN in Ireland
  cross_region_copy_retention_days = 365

  # Cross-Account Copy Config (Example: Prod Frankfurt to Backup Frankfurt)
  enable_cross_account_copy            = true
  cross_account_destination_vault_arn = "arn:aws:backup:eu-central-1:999988887777:backup-vault:prod-backup-target-vault" # Replace with actual Dest Vault ARN in Backup Account
  cross_account_copy_retention_days = 365 * 5 # 5 years
  source_account_id                    = data.aws_caller_identity.current.account_id # Pass current account ID for policy generation

  tags = {
    Terraform   = "true"
    Environment = "Production"
    ManagedBy   = "BackupModule"
  }
}

# Output the policy required for the cross-account destination vault
output "required_cross_account_policy" {
  description = "Policy JSON to apply to the cross-account destination vault."
  value       = module.prod_backup_policy.cross_account_destination_vault_policy_json
}
````

*(Note: Replace placeholder ARNs and tag values with your actual values).*

## INPUTS

| Name                                      | Description                                                                 | Type          | Default                        | Required               |
|-------------------------------------------|-----------------------------------------------------------------------------|---------------|-------------------------------|------------------------|
| policy_name                               | A unique name for the backup policy resources (plan, selection, vaults).   | string        | -                             | yes                    |
| tags                                      | A map of tags to apply to the created resources (plan, vaults, role).      | map(string)   | {}                            | no                     |
| backup_schedule                           | Cron expression for the backup frequency.                                   | string        | "cron(0 5 ? * * *)"          | no                     |
| primary_retention_days                   | Number of days to retain backups in the primary vault.                     | number        | 35                            | no                     |
| primary_kms_key_arn                      | ARN of the KMS key used to encrypt backups in the primary vault.           | string        | -                             | yes                    |
| resource_selection_tag_key_1              | The key of the first tag used for resource selection.                       | string        | "ToBackup"                    | no                     |
| resource_selection_tag_value_1            | The value of the first tag used for resource selection.                     | string        | "true"                        | no                     |
| resource_selection_tag_key_2              | The key of the second tag used for resource selection.                      | string        | "Owner"                       | no                     |
| resource_selection_tag_value_2            | The value of the second tag used for resource selection (e.g., email address). | string        | -                             | yes                    |
| primary_vault_name                       | Optional specific name for the primary backup vault. Defaults to <policy_name>-primary-vault-<region>. | string        | null                          | no                     |
| enable_primary_vault_lock                | If true, enables Vault Lock (WORM) on the primary vault.                   | bool          | true                          | no                     |
| vault_lock_min_retention_days            | Minimum retention period in days for Vault Lock (>= 1).                    | number        | 7                             | no                     |
| vault_lock_max_retention_days            | Maximum retention period in days for Vault Lock.                            | number        | 3650                          | no                     |
| vault_lock_changeable_for_days           | Number of days the Vault Lock is changeable before being locked immutably (>= 3). | number        | 3                             | no                     |
| enable_cross_region_copy                 | If true, enables copying backups to a different region within the same account. | bool          | true                          | no                     |
| cross_region_destination_vault_arn       | ARN of the pre-existing Backup Vault in the destination region.             | string        | null                          | yes (if enabled)       |
| cross_region_copy_retention_days         | Number of days to retain backups in the cross-region destination vault.     | number        | 180                           | no                     |
| cross_region_copy_kms_key_arn            | Optional: ARN of the KMS key in the destination region to encrypt copies.   | string        | null                          | no                     |
| enable_cross_account_copy                 | If true, enables copying backups to a different AWS account.                | bool          | true                          | no                     |
| cross_account_destination_vault_arn      | ARN of the pre-existing Backup Vault in the destination account.            | string        | null                          | yes (if enabled)       |
| cross_account_copy_retention_days        | Number of days to retain backups in the cross-account destination vault.    | number        | 365                           | no                     |
| cross_account_copy_kms_key_arn           | Optional: ARN of the KMS key in the destination account/region to encrypt copies. | string        | null                          | no                     |
| source_account_id                         | AWS Account ID where this module runs (for cross-account policy). Can often be derived via data source. | string        | null                          | yes (if enabled)       |
| backup_iam_role_name                     | Optional specific name for the AWS Backup IAM role. Defaults to <policy_name>-backup-role. | string        | null                          | no                     |


## 