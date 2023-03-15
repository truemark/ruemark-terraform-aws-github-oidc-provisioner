data "aws_caller_identity" "current" {}

#------------------------------------------------------------------------------
# OIDC Assumable Role - Github
#------------------------------------------------------------------------------

module "github_provisioner" {
  source = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "5.11.2"

  name = var.name
  tags = merge({
    Role = var.name
  }, var.tags)
  policies = var.role_policy_arns
  subjects = var.subjects
  path = var.path
  
}

#------------------------------------------------------------------------------
# Terraform S3 Access
#------------------------------------------------------------------------------
# This policy grants the provisioner user access to specific paths in the S3
# bucket holding terraform state. This is needed to prevent different
# provisioner users from stepping on one another's changes. Additionally, there
# is sensitive information stored in the state files in these S3 buckets which should be restricted.

locals {
  terraform_s3_bucket = var.terraform_s3_bucket == null ? "${data.aws_caller_identity.current.account_id}-terraform" : var.terraform_s3_bucket
  terraform_dynamodb_table = var.terraform_dynamodb_table == null ?"${data.aws_caller_identity.current.account_id}-terraform" : var.terraform_dynamodb_table
}

data "aws_iam_policy_document" "terraform" {
  statement {
    sid = "AllowBucketList"
    effect = "Allow"
    actions = ["s3:ListAllMyBuckets", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::*"]
  }
  statement {
    sid = "AllowListBucket"
    effect = "Allow"
    actions = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.terraform_s3_bucket}"]
  }
  statement {
    sid = "AllowPath"
    effect = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListObjects"]
    resources = ["arn:aws:s3:::${local.terraform_s3_bucket}/${var.terraform_s3_prefix}/*"]
  }
  statement {
    sid = "AllowWorkspacePath"
    effect = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListObjects"]
    resources = ["arn:aws:s3:::${local.terraform_s3_bucket}/env:/*/${var.terraform_s3_prefix}/*"]
  }
  statement {
    sid = "AllowDynamo"
    effect = "Allow"
    actions = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:DeleteItem"]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${local.terraform_dynamodb_table}"]
  }
}

resource "aws_iam_policy" "terraform" {
  count = var.create_role && var.create_terraform_policy ? 1 : 0
  name = "${var.name}-terraform"
  description = "Allows access to terraform state and locks."
  policy = data.aws_iam_policy_document.terraform.json
  tags = merge(var.tags, var.terraform_policy_tags)
  path = var.path
}

resource "aws_iam_role_policy_attachment" "terraform" {
  count = var.create_role && var.create_terraform_policy ? 1 : 0
  policy_arn = aws_iam_policy.terraform[count.index].arn
  role = module.github_provisioner.name
}

#------------------------------------------------------------------------------
# Additional Policies 
#------------------------------------------------------------------------------
resource "aws_iam_policy" "provisioner_n" {
  count = length(var.policies)
  name = "${var.name}-${count.index}"
  path = var.path
  description = "Access policy for IAM role ${var.name}"
  policy = var.policies[count.index]
}

resource "aws_iam_role_policy_attachment" "provisioner_n" {
  count = length(var.policies)
  policy_arn = aws_iam_policy.provisioner_n[count.index].arn
  role = module.github_provisioner.name
}
