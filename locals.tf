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

  rds = {
    identifier                  = "${naming_prefix}-rds-pg"
    engine                      = "postgres"
    engine_version              = "14"
    family                      = "postgres14"
    port                        = "5432"
    apply_immediately           = true
    publicly_accessible         = false
    create_db_subnet_group      = false
    manage_master_user_password = false
    skip_final_snapshot         = true

    instance_class      = "db.t3.micro"
    allocated_storage   = "10"
    deletion_protection = false

    username = random_pet.master.id
    password = random_password.master.result

    subnet_ids             = [for subnet_id in module.vpc.private_subnets : subnet_id]
    vpc_security_group_ids = [aws_security_group.rds_sg.id]
    db_subnet_group_name   = module.vpc.database_subnet_group
  }
}