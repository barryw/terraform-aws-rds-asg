
      ____  ____  ____       _    ____   ____
     |  _ \|  _ \/ ___|     / \  / ___| / ___|
     | |_) | | | \___ \    / _ \ \___ \| |  _
     |  _ <| |_| |___) |  / ___ \ ___) | |_| |
     |_| \_\____/|____/  /_/   \_\____/ \____|


#### Introduction

This is a Terraform module that allows you to control an RDS instance/cluster based on the number of EC2 instances attached to an AutoScaling Group.

You can use this for dev/qa/staging environments that you scale down to 0 nodes in off-hours/weekends. This would allow you to automatically stop the associated RDS resource when your dev/qa/staging AutoScaling Group scaled down to 0 nodes, and start it when the group scaled up > 0 EC2 instances.

This module is very similar to this one, but doesn't require you to create an associated schedule for your RDS resource: https://github.com/barryw/terraform-aws-rds-scheduler

The primary motivation is to be able to control costs for non-critical environments.


#### Usage

```hcl
module "rds_asg" {
  source = "github.com/barryw/terraform-aws-rds-asg"

  /* Don't stop RDS in production! */
  skip_execution = "${var.environment == "prod"}"
  identifier     = "${var.product_name}-${var.environment}"

  rds_identifier = "${data.aws_rds_cluster.rds.cluster_identifier}"
  is_cluster     = true

  asg_name       = "${data.aws_autoscaling_group.asg.name}"
}
```

##### License

This module is licensed under the MIT license: https://opensource.org/licenses/MIT
