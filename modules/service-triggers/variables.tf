variable "harness_account_id" {
  type        = string
  description = "Harness account identifier"
}

variable "org_id" {
  type        = string
  description = "Harness organization identifier where resources are created"
}

variable "project_id" {
  type        = string
  description = "Harness project identifier where triggers/input sets are created"
}

variable "repo_full_name" {
  type        = string
  description = "Full GitHub repo name, e.g. 'Kru3ish/service-a'"
}

variable "github_connector_ref" {
  type        = string
  description = "Harness GitHub connector reference, e.g. 'account.github'"
}

variable "pipeline_identifier" {
  type        = string
  description = "Identifier of the CI pipeline that triggers fire against"
}

variable "triggers_yaml_path" {
  type        = string
  default     = ".harness/triggers.yaml"
  description = "Path to triggers.yaml in the repo"
}

variable "repo_branch" {
  type        = string
  default     = "main"
  description = "Default branch of the repo"
}

variable "github_raw_base_url" {
  type        = string
  default     = "https://raw.githubusercontent.com"
  description = "Base URL for fetching raw GitHub content"
}

variable "github_token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "GitHub token for fetching triggers.yaml from private repos"
}

variable "harness_platform_api_key" {
  type        = string
  sensitive   = true
  description = "Harness platform API key for provider authentication"
}

