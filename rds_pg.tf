module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.7.0"

  identifier                  = local.rds.identifier
  engine                      = local.rds.engine
  engine_version              = local.rds.engine_version
  family                      = local.rds.family
  port                        = local.rds.port
  apply_immediately           = local.rds.apply_immediately
  publicly_accessible         = local.rds.publicly_accessible
  create_db_subnet_group      = local.rds.create_db_subnet_group
  manage_master_user_password = local.rds.manage_master_user_password
  skip_final_snapshot         = local.rds.skip_final_snapshot

  instance_class      = local.rds.instance_class
  allocated_storage   = local.rds.allocated_storage
  deletion_protection = local.rds.deletion_protection

  username = local.rds.username
  password = local.rds.password

  subnet_ids             = local.rds.subnet_ids
  vpc_security_group_ids = local.rds.vpc_security_group_ids
  db_subnet_group_name   = local.rds.db_subnet_group_name

}
