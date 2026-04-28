locals {
  triggers_config = yamldecode(data.http.triggers_yaml.response_body)

  # Build a map keyed by sanitized path for for_each
  trigger_map = {
    for t in local.triggers_config.triggers :
    replace(replace(t.path, "/", "_"), "*", "all") => t
  }

  repo_name = split("/", var.repo_full_name)[1]
}
