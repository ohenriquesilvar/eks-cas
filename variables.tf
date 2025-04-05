variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "cluster_autoscaler_version" {
  description = "Version of the Cluster Autoscaler"
  type        = string
  default     = "v1.29.0"
}
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"
}

