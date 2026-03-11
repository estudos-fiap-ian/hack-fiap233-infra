###############################################################################
# Network Load Balancer (internal)
###############################################################################

resource "aws_lb" "internal" {
  name               = "${var.project_name}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids

  tags = {
    Name = "${var.project_name}-nlb"
  }
}

###############################################################################
# Target Groups
###############################################################################

resource "aws_lb_target_group" "users" {
  name        = "${var.project_name}-tg-users"
  port        = var.node_port_users
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = tostring(var.node_port_users)
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.project_name}-tg-users"
  }
}

resource "aws_lb_target_group" "videos" {
  name        = "${var.project_name}-tg-videos"
  port        = var.node_port_videos
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = tostring(var.node_port_videos)
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name = "${var.project_name}-tg-videos"
  }
}

###############################################################################
# Listeners
###############################################################################

resource "aws_lb_listener" "users" {
  load_balancer_arn = aws_lb.internal.arn
  port              = var.nlb_port_users
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.users.arn
  }
}

resource "aws_lb_listener" "videos" {
  load_balancer_arn = aws_lb.internal.arn
  port              = var.nlb_port_videos
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.videos.arn
  }
}

###############################################################################
# Attach Node Group ASG to Target Groups
###############################################################################

resource "aws_autoscaling_attachment" "users" {
  autoscaling_group_name = var.node_group_asg_name
  lb_target_group_arn    = aws_lb_target_group.users.arn
}

resource "aws_autoscaling_attachment" "videos" {
  autoscaling_group_name = var.node_group_asg_name
  lb_target_group_arn    = aws_lb_target_group.videos.arn
}
