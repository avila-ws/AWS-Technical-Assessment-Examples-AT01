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

