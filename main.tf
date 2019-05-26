resource "aws_iam_role" "rds-asg" {
  name = "${var.identifier}-rds-asg"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

/* Find the AutoScaling Group specified. We need its ARN */
data "aws_autoscaling_group" "asg" {
  name = "${var.asg_name}"
}

/* Find the RDS Cluster. We need its ARN */
data "aws_rds_cluster" "rds-cluster" {
  count = "${var.is_cluster ? 1 : 0}"
  cluster_identifier = "${var.rds_identifier}"
}

/* Find the RDS Instance. We need its ARN */
data "aws_db_instance" "rds-instance" {
  count = "${var.is_cluster ? 0 : 1}"
  db_instance_identifier = "${var.rds_identifier}"
}

data "aws_iam_policy_document" "rds-asg-autoscaling" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups"
    ]
    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "rds-asg-rds-instance" {
  count = "${var.is_cluster ? 0 : 1}"
  statement {
    actions = [
      "rds:DescribeDBInstances",
      "rds:StartDBInstance",
      "rds:StopDBInstance",
    ]
    resources = [
      "${data.aws_db_instance.rds-instance.arn}"
    ]
  }
}

data "aws_iam_policy_document" "rds-asg-rds-cluster" {
  count = "${var.is_cluster ? 1 : 0}"
  statement {
    actions = [
      "rds:DescribeDBClusters",
      "rds:StartDBCluster",
      "rds:StopDBCluster"
    ]
    resources = [
      "${data.aws_rds_cluster.rds-cluster.arn}",
    ]
  }
}

resource "aws_iam_policy" "rds-asg-rds-cluster" {
  count = "${var.is_cluster ? 1 : 0}"
  name = "${var.identifier}-rds-asg-rds-cluster"
  path = "/"
  policy = "${data.aws_iam_policy_document.rds-asg-rds-cluster.json}"
}

resource "aws_iam_policy" "rds-asg-rds-instance" {
  count = "${var.is_cluster ? 0 : 1}"
  name = "${var.identifier}-rds-asg-rds-instance"
  path = "/"
  policy = "${data.aws_iam_policy_document.rds-asg-rds-instance.json}"
}

resource "aws_iam_policy" "rds-asg-rds-autoscaling" {
  name = "${var.identifier}-rds-asg-rds-autoscaling"
  path = "/"
  policy = "${data.aws_iam_policy_document.rds-asg-autoscaling.json}"
}

resource "aws_iam_role_policy_attachment" "rds-asg-cluster" {
  count      = "${var.is_cluster ? 1 : 0}"
  role       = "${aws_iam_role.rds-asg.name}"
  policy_arn = "${aws_iam_policy.rds-asg-rds-cluster.arn}"
}

resource "aws_iam_role_policy_attachment" "rds-asg-instance" {
  count      = "${var.is_cluster ? 0 : 1}"
  role       = "${aws_iam_role.rds-asg.name}"
  policy_arn = "${aws_iam_policy.rds-asg-rds-instance.arn}"
}

resource "aws_iam_role_policy_attachment" "rds-asg-autoscaling" {
  role       = "${aws_iam_role.rds-asg.name}"
  policy_arn = "${aws_iam_policy.rds-asg-rds-autoscaling.arn}"
}

/* Add a couple of managed policies to allow Lambda to write to CloudWatch & XRay */
resource "aws_iam_role_policy_attachment" "lambda-basic-execution" {
  role = "${aws_iam_role.rds-asg.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda-xray" {
  role = "${aws_iam_role.rds-asg.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

/* Create a zip file containing the lambda code */
data "archive_file" "rds-asg" {
  type        = "zip"
  source_dir = "${path.module}/package"
  output_path = "${path.module}/rds-asg.zip"
}

/* The lambda resource */
resource "aws_lambda_function" "rds-asg" {
  filename = "${data.archive_file.rds-asg.output_path}"
  function_name = "${var.identifier}-rds-asg"
  description = "Start and stop an RDS cluster/instance based on AutoScaling Group instance count"
  role = "${aws_iam_role.rds-asg.arn}"
  handler = "rds_asg.lambda_handler"
  runtime = "python3.7"
  timeout = 300
  source_code_hash = "${data.archive_file.rds-asg.output_base64sha256}"

  environment {
    variables = {
      RDS_IDENTIFIER = "${var.rds_identifier}"
      IS_CLUSTER = "${var.is_cluster}"
      SKIP_EXECUTION = "${var.skip_execution}"
      ASG_NAME = "${var.asg_name}"
    }
  }
}

/* Give our events permission to execute our Lambda */
resource "aws_lambda_permission" "up-asg" {
  statement_id = "AllowUpASGExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.rds-asg.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.up-asg.arn}"
}

resource "aws_lambda_permission" "down-asg" {
  statement_id = "AllowDownASGExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.rds-asg.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.down-asg.arn}"
}

resource "aws_cloudwatch_event_rule" "up-asg" {
  name = "${var.identifier}-up-asg"
  description = "The scale up rule for ${var.identifier} ASG"
  event_pattern = <<PATTERN
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance Launch Successful"
  ],
  "detail": {
    "AutoScalingGroupName": [
      "${var.asg_name}"
    ],
    "StatusCode": ["InProgress"]
  }
}
PATTERN
}

/* Calls the Lambda function when we detect instance launch */
/* on our autoscaling group. We need to see if the instance count */
/* is greater than 0 instances, at which point we'll start our RDS */
resource "aws_cloudwatch_event_target" "up-asg-target" {
  target_id = "${var.identifier}-up-asg"
  rule = "${aws_cloudwatch_event_rule.up-asg.name}"
  arn = "${aws_lambda_function.rds-asg.arn}"
}

resource "aws_cloudwatch_event_rule" "down-asg" {
  name = "${var.identifier}-down-asg"
  description = "The scale down rule for ${var.identifier} ASG"
  event_pattern = <<PATTERN
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance Terminate Successful"
  ],
  "detail": {
    "AutoScalingGroupName": [
      "${var.asg_name}"
    ],
    "StatusCode": ["InProgress"]
  }
}
PATTERN
}

/* Calls the Lambda function when we detect instance termination */
/* on our autoscaling group. We need to see if the instance count */
/* has reached 0 instances, at which point we'll stop our RDS */
resource "aws_cloudwatch_event_target" "down-asg-target" {
  target_id = "${var.identifier}-down-asg"
  rule = "${aws_cloudwatch_event_rule.down-asg.name}"
  arn = "${aws_lambda_function.rds-asg.arn}"
}
