data "aws_ami" "ubuntu_latest" {
  description = "Fetches the most recent Ubuntu 22.04 LTS (Jammy) AMI with HVM and SSD support."
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
