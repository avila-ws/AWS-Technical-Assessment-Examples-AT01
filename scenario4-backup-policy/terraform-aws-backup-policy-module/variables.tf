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