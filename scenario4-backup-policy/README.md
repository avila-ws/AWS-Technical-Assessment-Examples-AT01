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

*(Placeholder: This section will show a simple `main.tf` in the `scenario4-backup-policy` folder demonstrating how to call the created module with example inputs).*

## 6. References

*(Placeholder: Links to AWS Backup, Terraform AWS Provider documentation).*

---
*This concludes the analysis and plan for Scenario 4.*
