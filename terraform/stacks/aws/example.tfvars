hosted_zone_id        = "Z0123456789ABCDEFGHIJ"
github_subject_prefix = "repo:owner/site-repo"

site = {
  bucket_name = "example-site"
  domains     = ["www.example.com"]
}

cms = {
  bucket_name        = "example-site-cms"
  domain             = "cms.example.com"
  allowed_ipv4_cidrs = ["203.0.113.0/24"]
}
