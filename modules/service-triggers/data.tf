data "http" "triggers_yaml" {
  url = "https://api.github.com/repos/${var.repo_full_name}/contents/${var.triggers_yaml_path}?ref=${var.repo_branch}"

  request_headers = var.github_token != "" ? {
    Accept        = "application/vnd.github.v3.raw"
    Authorization = "token ${var.github_token}"
  } : {
    Accept = "application/vnd.github.v3.raw"
  }
}
