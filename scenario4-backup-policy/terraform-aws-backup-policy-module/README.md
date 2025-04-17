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
