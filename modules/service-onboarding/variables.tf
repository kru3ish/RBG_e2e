variable "service_name" {
  type        = string
  description = "Service name — becomes the GitHub repo name (lowercase, alphanumeric + hyphens)"
}

variable "repo_org" {
  type        = string
  default     = "Kru3ish"
  description = "GitHub user or organization for the new repo"
}

variable "target_org" {
  type        = string
  default     = "Harness_Platform_Management"
  description = "Harness org where service resources are created"
}

variable "target_project" {
  type        = string
  default     = "Solutions_Factory"
  description = "Harness project where service resources are created"
}

variable "hsf_org" {
  type        = string
  default     = "Harness_Platform_Management"
  description = "Harness org where HSF pipelines and workspaces live"
}

variable "hsf_project" {
  type        = string
  default     = "Solutions_Factory"
  description = "Harness project where HSF pipelines and workspaces live"
}

variable "pipeline_template_id" {
  type        = string
  default     = "Build_and_Push"
  description = "CI pipeline identifier that triggers fire against"
}

variable "github_connector_ref" {
  type        = string
  default     = "account.github"
  description = "Harness GitHub connector reference for webhooks"
}

variable "harness_account_id" {
  type        = string
  description = "Harness account identifier"
}

variable "harness_platform_api_key" {
  type        = string
  sensitive   = true
  description = "Harness platform API key"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "GitHub personal access token for repo creation and file seeding"
}
