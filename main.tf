// fetch an ECS optimised Amazon AMI in the selected region
data "aws_ami" "amazon_ecs_ami" {
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

resource "aws_security_group" "ecs_sg" {
  name        = "ecs_sg"
  vpc_id      = "${var.vpc_id}"
  description = "ECS nodes default security group"

  tags {
    Name = "${var.cluster_name}"
  }

  ingress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "ecs_conf" {
  name                        = "${var.cluster_name}-LC"
  image_id                    = "${data.aws_ami.amazon_ecs_ami.id}"
  iam_instance_profile        = "${aws_iam_instance_profile.cluster.name}"
  instance_type               = "${var.type}"
  key_name                    = "${var.key_name}"
  associate_public_ip_address = false
  security_groups             = ["${aws_security_group.ecs_sg.id}"]

  lifecycle {
    create_before_destroy = true
  }

  user_data = "${data.template_file.user_data.rendered}"
}

resource "aws_autoscaling_policy" "scale_out" {
  adjustment_type = "ChangeInCapacity"
  policy_type     = "StepScaling"

  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = "0"
    metric_interval_upper_bound = ""
  }

  autoscaling_group_name = "${aws_autoscaling_group.ecs.name}"
  name                   = "simple_scale_out"
}

resource "aws_cloudwatch_metric_alarm" "cpu_greater_than" {
  alarm_name          = "cpu_usage_greater_than"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.ecs.name}"
  }

  alarm_description = "This metric monitors EC2 CPU utilisation greater than 80%"
  alarm_actions     = ["${aws_autoscaling_policy.scale_out.arn}"]
}

resource "aws_autoscaling_policy" "scale_in" {
  adjustment_type = "ChangeInCapacity"
  policy_type     = "StepScaling"

  step_adjustment {
    scaling_adjustment          = "-1"
    metric_interval_lower_bound = ""
    metric_interval_upper_bound = "0"
  }

  autoscaling_group_name = "${aws_autoscaling_group.ecs.name}"
  name                   = "simple_scale_in"
}

resource "aws_cloudwatch_metric_alarm" "cpu_less_than" {
  alarm_name          = "cpu_usage_less_than"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 20

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.ecs.name}"
  }

  alarm_description = "This metric monitors EC2 CPU utilisation less than 20%"
  alarm_actions     = ["${aws_autoscaling_policy.scale_in.arn}"]
}

resource "aws_autoscaling_group" "ecs" {
  name                      = "${var.cluster_name}-ASG"
  launch_configuration      = "${aws_launch_configuration.ecs_conf.name}"
  vpc_zone_identifier       = ["${split(",", var.subnet_id)}"]
  max_size                  = "${var.cluster_max_size}"
  min_size                  = "${var.cluster_min_size}"
  default_cooldown          = 60
  health_check_type         = "EC2"
  health_check_grace_period = "10"
  termination_policies      = ["OldestInstance"]

  enabled_metrics = [
    "GroupMaxSize",
    "GroupMinSize",
    "GroupInServiceInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "ecs-node"
  }
}
