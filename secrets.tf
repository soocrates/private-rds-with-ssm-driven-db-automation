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
