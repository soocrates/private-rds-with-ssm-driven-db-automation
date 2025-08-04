locals {
  tags = {
    environment     = "development"
    operationsOwner = "DevOps"
    project         = "agrow"
    createdBy       = "roshan.poudel"
    terraform       = true
  }

  naming_prefix = "${var.project_name}-${var.region_short_name}"
  number_of_azs = 2
  vpc = {
    vpc_cidr               = "10.0.0.0/16"
    azs                    = slice(data.aws_availability_zones.available.names, 0, local.number_of_azs)
    single_nat_gateway     = true
    one_nat_gateway_per_az = false
  }
}