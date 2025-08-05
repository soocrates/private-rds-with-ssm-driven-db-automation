resource "aws_iam_role" "ssm_ec2_role" {
  name = "${local.naming_prefix}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${local.naming_prefix}-ec2-ssm-profile"
  role = aws_iam_role.ssm_ec2_role.name
}

resource "aws_iam_role_policy" "secrets_policy" {
  name = "${local.naming_prefix}-allow-secret-reading-policy"
  role = aws_iam_role.ssm_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "secretsmanager:GetSecretValue",
      Resource = "*"
    }]
  })
}
