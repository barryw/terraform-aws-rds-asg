variable "identifier" {
  description = "A unique name for this product/environment"
}

variable "skip_execution" {
  description = "You may not want to run this in certain environments. Set this to an expression that returns true and the associated RDS instance won't be stopped."
  default = false
}

variable "rds_identifier" {
  description = "The RDS identifier of the instance/cluster you want managed"
}

variable "is_cluster" {
  description = "Is this a cluster or an instance?"
  default = true
}

variable "asg_name" {
  description = "The name of the autoscaling group to watch."
}
