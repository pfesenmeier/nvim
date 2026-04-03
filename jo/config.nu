export def get_config []: nothing -> record<job_dir: string, job_defs: record<path: string, command: string, is_global?: bool>> {
  let config_path = $nu.home-dir | path join .config jo
  let job_dir = $config_path | path join "jobs"
  let dynamic_config = find_dynamic_config
  
  {
    job_dir: $job_dir,
    job_defs: $dynamic_config.jobs
  }
}

def find_dynamic_config []: nothing -> record<jobs: record<path: string, command: string, is_global?: bool>>  {
  let config_json = $nu.home-dir | path join ".jo.config.json"

  # TODO Validate

  open $config_json
}
