variable "harness_account_id" {
  type        = string
  description = "Harness account identifier"
}

variable "org_id" {
  type        = string
  description = "Harness organization identifier where the trigger will be created"
}

variable "project_id" {
  type        = string
  description = "Harness project identifier where the trigger will be created"
}

variable "target_workspace_id" {
  type        = string
  description = "Identifier of the IACM workspace to apply on file change"
}

variable "target_pipeline_id" {
  type        = string
  description = "Pipeline identifier that provisions the target workspace"
  default     = "Provision_Workspace"
}

variable "repo_org" {
  type        = string
  description = "GitHub organization group (RBG, IAA, kru3ish, etc.)"
}

variable "repo_name" {
  type        = string
  description = "Repository name within the org"
}

variable "file_paths" {
  type        = string
  description = "Comma-separated list of file paths to watch"
  default     = ".harness/triggers.yaml"
}

variable "branch" {
  type        = string
  description = "Git branch to watch"
  default     = "main"
}

variable "connector_map" {
  type        = map(string)
  description = "Mapping of repo org to Harness GitHub connector reference"
  default = {
    "kru3ish" = "account.github"
    "RBG"     = "account.github"
    "IAA"     = "account.github"
  }
}

variable "default_connector" {
  type        = string
  description = "Default GitHub connector if repo_org not in connector_map"
  default     = "account.github_public"
}
