resource "aws_instance" "rds_connector" {
  ami                         = "ami-020cba7c55df1f615"
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.rds_connector_ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "${local.naming_prefix}-rds-connector"
  }
  depends_on = [module.rds]
}

resource "null_resource" "configure_instance" {
  triggers = {
    instance_id   = aws_instance.rds_connector.id
    document_hash = sha256(aws_ssm_document.install_tools.content)
  }

  depends_on = [
    aws_instance.rds_connector,
    module.rds
  ]

  provisioner "local-exec" {
    command     = <<-EOT
      #!/bin/bash
      set -e
      echo ">>> STAGE 1: Configuring instance ${self.triggers.instance_id} with required tools..."
      COMMAND_ID=$(aws ssm send-command --instance-ids "${self.triggers.instance_id}" --document-name "${aws_ssm_document.install_tools.name}" --query "Command.CommandId" --output text)
      echo "Configuration command sent. Waiting for completion... (Command ID: $COMMAND_ID)"
      aws ssm wait command-executed --command-id $COMMAND_ID --instance-id "${self.triggers.instance_id}"
      STATUS=$(aws ssm list-command-invocations --command-id $COMMAND_ID --details --query "CommandInvocations[0].Status" --output text)
      if [ "$STATUS" != "Success" ]; then
        echo "ERROR: Instance configuration failed with status: $STATUS"
        aws ssm get-command-invocation --command-id $COMMAND_ID --instance-id "${self.triggers.instance_id}" --query "StandardErrorContent" --output text
        exit 1
      fi
      echo ">>> STAGE 1: Instance configuration successful. <<<"
    EOT
    interpreter = ["bash", "-c"]
  }
}

resource "null_resource" "invoke_db_creator" {
  for_each = toset(var.app_db_names)

  triggers = {
    instance_id   = aws_instance.rds_connector.id
    db_name       = each.key
    db_host       = module.rds.db_instance_address
    document_hash = sha256(aws_ssm_document.db_creator.content)
    app_secret    = module.app_db_secrets[each.key].secret_arn
    master_secret = module.master_secret.secret_arn
  }

  depends_on = [
    null_resource.configure_instance,
    aws_instance.rds_connector,
    module.rds,
    module.app_db_secrets,
    module.master_secret,
    aws_ssm_document.db_creator
  ]

  provisioner "local-exec" {
    command     = <<-EOT
      #!/bin/bash
      set -e
      echo ">>> STAGE 2: Sending command for database: ${self.triggers.db_name}..."

      COMMAND_ID=$(aws ssm send-command \
        --instance-ids "${self.triggers.instance_id}" \
        --document-name "${aws_ssm_document.db_creator.name}" \
        --parameters "NewDBName=['${self.triggers.db_name}'],NewUserPasswordSecretArn=['${self.triggers.app_secret}'],MasterSecretArn=['${self.triggers.master_secret}'],DBHost=['${self.triggers.db_host}']" \
        --query "Command.CommandId" \
        --output text)

      echo "Waiting for DB creation for ${self.triggers.db_name}... (Command ID: $COMMAND_ID)"
      aws ssm wait command-executed --command-id $COMMAND_ID --instance-id "${self.triggers.instance_id}"

      STATUS=$(aws ssm list-command-invocations --command-id $COMMAND_ID --details --query "CommandInvocations[0].Status" --output text)
      if [ "$STATUS" != "Success" ]; then
          echo "ERROR: DB creation command failed for ${self.triggers.db_name} with status: $STATUS"
          aws ssm get-command-invocation --command-id $COMMAND_ID --instance-id "${self.triggers.instance_id}" --query "StandardErrorContent" --output text
          exit 1
      fi

      echo ">>> STAGE 2: Database ${self.triggers.db_name} created successfully. <<<"
    EOT
    interpreter = ["bash", "-c"]
  }
}
