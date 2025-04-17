# ------------------------------------------------------------------------------
# Input Variables for the AWS Backup Policy Module
# ------------------------------------------------------------------------------

# --- General Configuration ---

variable "policy_name" {
  description = "A unique name for the backup policy resources (plan, selection, vaults)."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the created resources (plan, vaults, role)."
  type        = map(string)
  default     = {}
}

# --- Backup Plan: Rule Configuration ---

variable "backup_schedule" {
  description = "Cron expression for the backup frequency (e.g., 'cron(0 5 ? * * *)' for daily at 5 AM UTC)."
  type        = string
  default     = "cron(0 5 ? * * *)" # Default: Daily at 5 AM UTC
}

variable "primary_retention_days" {
  description = "Number of days to retain backups in the primary vault."
  type        = number
  default     = 35 # Default: 35 days
}

variable "primary_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt backups in the primary vault. Must exist in the same region as the primary vault."
  type        = string
  # No default - must be provided
}

# --- Backup Selection: Tag-Based ---

variable "resource_selection_tag_key_1" {
  description = "The key of the first tag used for resource selection."
  type        = string
  default     = "ToBackup"
}

variable "resource_selection_tag_value_1" {
  description = "The value of the first tag used for resource selection."
  type        = string
  default     = "true"
}

variable "resource_selection_tag_key_2" {
  description = "The key of the second tag used for resource selection."
  type        = string
  default     = "Owner"
}

variable "resource_selection_tag_value_2" {
  description = "The value of the second tag used for resource selection (e.g., email address)."
  type        = string
  # No default - must be provided
}

# --- Vault Configuration ---

variable "primary_vault_name" {
  description = "Optional specific name for the primary backup vault. Defaults to '<policy_name>-primary-vault'."
  type        = string
  default     = null
}

variable "enable_primary_vault_lock" {
  description = "If true, enables Vault Lock (WORM) on the primary vault."
  type        = bool
  default     = true # Default based on requirements
}

variable "vault_lock_min_retention_days" {
  description = "Minimum retention period in days for Vault Lock. Must be >= 1."
  type        = number
  default     = 7
}

variable "vault_lock_max_retention_days" {
  description = "Maximum retention period in days for Vault Lock."
  type        = number
  default     = 3650 # Default: 10 years
}

variable "vault_lock_changeable_for_days" {
  description = "Number of days the Vault Lock is changeable before being locked immutably (cooling-off period). Min 3 days."
  type        = number
  default     = 3
}

# --- Cross-Region Copy Configuration (Optional) ---

variable "enable_cross_region_copy" {
  description = "If true, enables copying backups to a different region within the same account."
  type        = bool
  default     = true # Default based on requirements
}

variable "cross_region_destination_vault_arn" {
  description = "ARN of the pre-existing Backup Vault in the destination region (e.g., Ireland)."
  type        = string
  default     = null # Required if enable_cross_region_copy is true
}

variable "cross_region_copy_retention_days" {
  description = "Number of days to retain backups in the cross-region destination vault."
  type        = number
  default     = 180 # Default: 6 months
}

variable "cross_region_copy_kms_key_arn" {
  description = "Optional: ARN of the KMS key in the destination region to encrypt the copied backups. If null, uses the AWS Backup service default key in that region."
  type        = string
  default     = null
}

# --- Cross-Account Copy Configuration (Optional) ---

variable "enable_cross_account_copy" {
  description = "If true, enables copying backups to a different AWS account."
  type        = bool
  default     = true # Default based on requirements
}

variable "cross_account_destination_vault_arn" {
  description = "ARN of the pre-existing Backup Vault in the destination account (e.g., Backup Account Frankfurt)."
  type        = string
  default     = null # Required if enable_cross_account_copy is true
}

variable "cross_account_copy_retention_days" {
  description = "Number of days to retain backups in the cross-account destination vault."
  type        = number
  default     = 365 # Default: 1 year
}

variable "cross_account_copy_kms_key_arn" {
  description = "Optional: ARN of the KMS key in the destination account/region to encrypt the copied backups. If null, uses the AWS Backup service default key there."
  type        = string
  default     = null
}

variable "source_account_id" {
  description = "The AWS Account ID where this module is deployed. Used for generating the destination vault policy output. Can often be derived via data source."
  type        = string
  default     = null # Can be retrieved using 'data "aws_caller_identity" "current" {}'
}

# --- IAM Role ---
variable "backup_iam_role_name" {
  description = "Optional specific name for the AWS Backup IAM role. Defaults to '<policy_name>-backup-role'."
  type        = string
  default     = null
}
