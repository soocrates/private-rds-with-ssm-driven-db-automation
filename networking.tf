module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${naming_prefix}-vpc"
  cidr = local.vpc.vpc_cidr

  azs             = local.vpc.azs
  private_subnets = [for k, v in local.vpc.azs : cidrsubnet(local.vpc.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.vpc.azs : cidrsubnet(local.vpc.vpc_cidr, 4, k + 4)]

  single_nat_gateway           = true
  one_nat_gateway_per_az       = false
  create_database_subnet_group = true

  tags = local.tags
}
