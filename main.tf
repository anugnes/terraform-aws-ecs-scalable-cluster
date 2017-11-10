// fetch an ECS optimised Amazon AMI in the selected region
data "aws_ami" "amazon_ecs_os" {
  most_recent = true

  filter {
    name   = "name"
    values = ["*-amazon-ecs-optimized"]
    values = ["hvm"]
  }

  owners = ["amazon"]
}

data "template_file" "iam_role" {
  template = "${file("${path.module}/templates/iam_role.json")}"
}

data "template_file" "policy" {
  template = "${file("${path.module}/templates/policy.json")}"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user_data.sh")}"

  vars {
    cluster_name = "${aws_ecs_cluster.cluster.name}"
  }
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.cluster_name}"
}

resource "aws_iam_role" "ecs_cluster" {
  name               = "${var.role_name}"
  assume_role_policy = "${data.template_file.iam_role.rendered}"
}

resource "aws_iam_role_policy" "ecs_cluster" {
  name   = "${var.role_policy_name}"
  role   = "${aws_iam_role.ecs_cluster.id}"
  policy = "${data.template_file.policy.rendered}"
}

resource "aws_iam_instance_profile" "cluster" {
  name = "${var.instance_profile_name}"
  role = "${aws_iam_role.ecs_cluster.name}"
}

resource "aws_launch_configuration" "ecs_conf" {
  name                 = "${var.cluster_name}-LC"
  image_id             = "${data.aws_ami.amazon_ecs_os.id}"
  iam_instance_profile = "${aws_iam_instance_profile.cluster.name}"
  instance_type        = "${var.type}"
  key_name             = "${var.key_name}"

  lifecycle {
    create_before_destroy = true
  }

  user_data = "${data.template_file.user_data.rendered}"
}

resource "aws_autoscaling_group" "ecs" {
  name                 = "${var.cluster_name}-ASG"
  launch_configuration = "${aws_launch_configuration.ecs_conf.name}"
  vpc_zone_identifier  = ["${element(split(",", var.subnet_id), count.index)}"]
  max_size             = "${var.cluster_max_size}"
  min_size             = "${var.cluster_min_size}"
}