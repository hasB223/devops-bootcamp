data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "my_ssm_role" {
  name               = "Rackula-SSM-Role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# AWS managed policy granting Systems Manager (SSM) access
resource "aws_iam_role_policy_attachment" "my_ssm_core" {
  role       = aws_iam_role.my_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "my_ssm_profile" {
  name = "rackula-ssm-instance-profile"
  role = aws_iam_role.my_ssm_role.name
}