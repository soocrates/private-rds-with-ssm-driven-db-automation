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

  name_prefix             = "${naming_prefix}-master-db-secrets"
  description             = "Master DB credentials"
  recovery_window_in_days = 7
  enable_rotation         = false

  secret_string = jsonencode({
    username = random_pet.master.id
    password = random_password.master.result
    db_host  = module.rds.db_instance_endpoint
  })
}

resource "random_password" "app_db_passwords" {
  for_each         = toset(var.app_db_names)
  length           = 20
  special          = true
  override_special = "!#%&_-"
}

resource "random_pet" "app_db_usernames" {
  for_each  = toset(var.app_db_names)
  length    = 2
  prefix    = "dbuser"
  separator = "_"
}

module "app_db_secrets" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "1.3.1"

  for_each = toset(var.app_db_names)

  name_prefix             = "${naming_prefix}-${each.key}-db-secrets"
  description             = "App DB credentials for ${each.key}"
  recovery_window_in_days = 7
  enable_rotation         = false

  secret_string = jsonencode({
    username = random_pet.app_db_usernames[each.key].id
    password = random_password.app_db_passwords[each.key].result
    db_name  = each.key
    db_host  = module.rds.db_instance_endpoint
  })

}
