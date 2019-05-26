output "scheduler_role_arn" {
  value = "${aws_iam_role.rds-asg.arn}"
  description = "The arn of the role created for the start/stop Lambda"
}

output "scheduler_lambda_arn" {
  value = "${aws_lambda_function.rds-asg.arn}"
  description = "The arn of the start/stop Lambda function"
}

output "down_schedule_target_arn" {
  value = "${aws_cloudwatch_event_target.down-asg-target.arn}"
  description = "The arn of the down asg target"
}

output "up_schedule_target_arn" {
  value = "${aws_cloudwatch_event_target.up-asg-target.arn}"
  description = "The arn of the up asg target"
}

output "down_schedule_rule_arn" {
  value = "${aws_cloudwatch_event_rule.down-asg.arn}"
  description = "The arn of the down asg rule"
}

output "up_schedule_rule_arn" {
  value = "${aws_cloudwatch_event_rule.up-asg.arn}"
  description = "The arn of the up asg rule"
}
