data "aws_ami" "ubuntu_latest" {
  most_recent = true
  owners      = ["099720109477"] 
  filter {
    name   = "name"
    values = [
      "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    ]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "rds_connector" {
  ami                         = data.aws_ami.ubuntu_latest.id
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