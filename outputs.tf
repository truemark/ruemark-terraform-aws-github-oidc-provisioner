output "role_name" {
  value = module.github_provisioner.name
}

output "role_arn" {
  value = module.github_provisioner.arn
}

output "role_id" {
  value = module.github_provisioner.unique_id
}

output "role_path" {
  value = module.github_provisioner.path
}

output "terraform_policy_name" {
  value = join("", aws_iam_policy.terraform.*.name)
}

output "terraform_policy_arn" {
  value = join("", aws_iam_policy.terraform.*.arn)
}

output "terraform_policy_id" {
  value = join("", aws_iam_policy.terraform.*.id)
}
