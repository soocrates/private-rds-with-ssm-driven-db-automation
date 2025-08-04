resource "random_password" "master" {
  length           = 20
  special          = true
  override_special = "!#%&_-"
}

resource "random_pet" "master" {
  length    = 2
  prefix    = "dbuser"
  separator = "_"
}

module "master_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "1.3.1"

  name_prefix             = "${naming_prefix}-masterdb-secrets"
  description             = "Master DB credentials"
  recovery_window_in_days = 7
  enable_rotation         = false

  secret_string = jsonencode({
    username = random_pet.master.id
    password = random_password.master.result
    db_host  = module.rds.db_instance_endpoint
  })
}