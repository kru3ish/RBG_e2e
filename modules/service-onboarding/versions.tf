terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    harness = {
      source  = "harness/harness"
      version = "~> 0.32"
    }
  }
}
