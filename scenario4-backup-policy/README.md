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
