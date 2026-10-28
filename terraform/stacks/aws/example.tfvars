hosted_zone_id        = "Z0123456789ABCDEFGHIJ"
github_subject_prefix = "repo:owner/site-repo"

site = {
  bucket_name = "example-site"
  domains     = ["www.example.com"]
}

admin = {
  bucket_name        = "example-site-admin"
  domain             = "cms.example.com"
  allowed_ipv4_cidrs = ["203.0.113.0/24"]
}

preview = {
  bucket_name = "example-site-preview"
  domain      = "preview.example.com"
}
