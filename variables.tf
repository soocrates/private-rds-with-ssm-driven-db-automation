variable "region" {
  description = "The AWS region in which resources will be deployed (e.g., us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project or infrastructure module (e.g., rds-ssm-dbauto)."
  type        = string
  default     = "rds-ssm-dbautomation"
}

variable "region_short_name" {
  description = "Shortened identifier for the AWS region (e.g., us-east-1 becomes ue1). Useful for naming resources."
  type        = string
  default     = "ue1"
}