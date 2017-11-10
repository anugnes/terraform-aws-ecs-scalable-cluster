variable "cluster_name" {
  description = "The name of your ECS cluster"
}
variable "role_name" {
  description = "Role Name"
}
variable "role_policy_name" {
  description = "Role Policy Name"
}
variable "instance_profile_name" {
  description = "EC2 Instance Profile Name"
}
variable "type" {
  description = "EC2 Instance Type"
}
variable "cluster_max_size" {
  description = "Max number of EC2 instances in the cluster"
}
variable "cluster_min_size" {
  description = "Min number of EC2 instances in the cluster"
}
variable "subnet_id" {
  description = "List of subnet IDs to use when spinning up your cluster"
}
variable "key_name" {
  description = "AWS Key Pair to use for instances in the cluster"
}