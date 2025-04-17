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

# ---