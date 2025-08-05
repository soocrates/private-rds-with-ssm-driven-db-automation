module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "6.0.0"

  name = "${local.naming_prefix}-vpc"
  cidr = local.vpc.vpc_cidr

  azs             = local.vpc.azs
  private_subnets = [for k, v in local.vpc.azs : cidrsubnet(local.vpc.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.vpc.azs : cidrsubnet(local.vpc.vpc_cidr, 4, k + 4)]

  single_nat_gateway           = true
  one_nat_gateway_per_az       = false
  create_database_subnet_group = true

  tags = local.tags
}

resource "aws_security_group" "rds_sg" {
  name        = "${local.naming_prefix}-db-sg"
  description = "Allows PostgreSQL access"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}