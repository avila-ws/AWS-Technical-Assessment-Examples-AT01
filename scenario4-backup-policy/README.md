# Scenario 4: Backup Policy Leveraging AWS Backup via Terraform Module

## 1. Objective

The requirement is to implement a comprehensive cloud backup policy on AWS using the **AWS Backup** service. Automation is crucial for deployment at scale. This will be achieved by creating a reusable **Terraform module** that encapsulates all the specified technical details and requirements.

The module itself does not need to be fully "production-ready" but must accurately reflect the required configuration and demonstrate knowledge of AWS Backup and Terraform best practices.

## 2. Requirements Analysis

Based on the provided diagram and technical details, the Terraform module must configure the following components:

*   **Primary Backup Vault:** An encrypted vault in the primary region (e.g., Frankfurt) within the main account (e.g., "Prod").
*   **Destination Vaults (Optional):**
    *   An encrypted vault for cross-region copies within the main account (e.g., Ireland).
    *   An encrypted vault for cross-account copies in a separate backup account (e.g., Frankfurt).
*   **Vault Lock (WORM):** Option to enable Vault Lock on any created/managed vault to prevent deletion.
*   **IAM Role:** A dedicated IAM Role for AWS Backup service actions.
*   **Backup Plan:** A plan defining:
    *   Backup rules (frequency, primary retention).
    *   Encryption for backups in the primary vault (using a provided KMS Key ARN).
    *   Optional `copy_action` for cross-region backups (with frequency, retention, KMS Key ARN).
    *   Optional `copy_action` for cross-account backups (with frequency, retention, KMS Key ARN).
*   **Resource Selection:** A mechanism to select resources based on specific tags (`ToBackup=true` AND `Owner=<email>`).

## 3. Terraform Module Design

A dedicated Terraform module (`terraform-aws-backup-policy-module`) will be created to manage these resources.

### 3.1. Module Structure

The module will follow standard Terraform structure:

*   `main.tf`: Defines the core resources (`aws_backup_plan`, `aws_backup_selection`, `aws_backup_vault`, `aws_backup_vault_lock_configuration`).
*   `variables.tf`: Declares input variables for customization (names, schedules, retention periods, KMS ARNs, tag values, destination vault ARNs, feature flags like `enable_cross_region_copy`, `enable_cross_account_copy`, `enable_vault_lock`, etc.).
*   `outputs.tf`: Defines outputs from the module (e.g., ARNs of created plan and vaults).
*   `iam.tf`: Defines the `aws_iam_role` and `aws_iam_policy_attachment` needed for AWS Backup.
*   `README.md`: Documentation *within the module folder* explaining its inputs, outputs, and usage.

### 3.2. Mapping Requirements to Terraform Resources

*   **Vaults:** `aws_backup_vault` resources, potentially controlled by `count` based on boolean enable flags. KMS encryption key ARN provided via variable.
*   **Vault Lock:** `aws_backup_vault_lock_configuration` resource, potentially controlled by `count`.
*   **IAM Role:** `aws_iam_role`, `aws_iam_policy_attachment` (using `AWSBackupServiceRolePolicyForBackup`).
*   **Plan:** `aws_backup_plan` with nested `rule` block(s).
    *   Rule `lifecycle`: For primary retention (`delete_after_days`).
    *   Rule `copy_action`: Dynamic blocks (`for_each` on a map or using `count`) triggered by boolean enable flags, configuring `destination_vault_arn` and nested `lifecycle`.
*   **Selection:** `aws_backup_selection` linked to the plan ID, using `selection_tag` blocks (requiring `type = "STRINGEQUALS"`) and referencing the IAM role ARN.
*   **KMS Keys:** The module **will not create** KMS keys; their ARNs must be provided as input variables.

### 3.3. Handling Cross-Account Copies

*   The Terraform module, when executed within the primary account (e.g., "Prod"), will configure the `copy_action` in the `aws_backup_plan` to *target* the ARN of the backup vault in the separate "Backup" account.
*   However, for the copy to succeed, the destination vault in the "Backup" account requires a **Vault Access Policy** explicitly granting the primary account permission (`backup:CopyIntoBackupVault`).
*   This module **cannot directly apply** the policy to the vault in the other account (without assuming roles/multiple providers, adding unnecessary complexity for this evaluation).
*   **Solution:** The module will **generate the required JSON policy** based on the primary account ID (obtained via data source or variable) and expose it as a Terraform **output** (`cross_account_destination_vault_policy_json`).
*   **Action Required:** This output JSON policy must then be manually applied (or applied via a separate Terraform configuration run in the context of the "Backup" account) to the `aws_backup_vault_policy` resource associated with the destination vault. This demonstrates knowledge of the cross-account mechanism securely and pragmatically.

## 4. Module Implementation Details

*(Placeholder: This section will later contain the actual code for `variables.tf`, `main.tf`, `outputs.tf`, `iam.tf` from the module folder).*

## 5. Example Module Usage

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

## 6. References

*   **AWS Backup Documentation:**
    *   [AWS Backup Developer Guide](https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html)
    *   [Working with Backup Plans](https://docs.aws.amazon.com/aws-backup/latest/devguide/about-backup-plans.html)
    *   [Working with Backup Vaults](https://docs.aws.amazon.com/aws-backup/latest/devguide/about-backup-vaults.html)
    *   [AWS Backup Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html)
    *   [Assigning resources using tags](https://docs.aws.amazon.com/aws-backup/latest/devguide/assigning-resources.html#assigning-resources-tags)
    *   [Cross-account backup](https://docs.aws.amazon.com/aws-backup/latest/devguide/cross-account-backup.html)
    *   [Cross-region backup](https://docs.aws.amazon.com/aws-backup/latest/devguide/cross-region-backup.html)
    *   [Using service-linked roles for AWS Backup](https://docs.aws.amazon.com/aws-backup/latest/devguide/iam-service-linked-role.html) (Mentions the IAM role used)
*   **Terraform AWS Provider Documentation:**
    *   [AWS Provider - Backup Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) (Navega desde aquí a `aws_backup_vault`, `aws_backup_selection`, `aws_backup_vault_lock_configuration`, `aws_backup_vault_policy`)
    *   [Resource: aws_backup_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan)
    *   [Resource: aws_backup_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault)
    *   [Resource: aws_backup_selection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection)
    *   [Resource: aws_backup_vault_lock_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration)
    *   [Resource: aws_backup_vault_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_policy) (Importante para aplicar la política cross-account)
    *   [Resource: aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)
    *   [Data Source: aws_iam_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)

---
*This concludes the analysis and plan for Scenario 4.* 
