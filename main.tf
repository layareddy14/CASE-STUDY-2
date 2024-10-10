provider "aws" {
  region = "ap-south-1"  # Change to your desired region
}

# VPC and Subnets
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"

}


# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the Route Table with the Subnets
resource "aws_route_table_association" "subnet_a_association" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "subnet_b_association" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public_route_table.id
}


# Security Group
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template for EC2 Instances
resource "aws_launch_template" "app" {
  name_prefix   = "app-template"
  image_id      = "ami-0522ab6e1ddcc7055"  # Update with your AMI
  instance_type = "t2.micro"  # Change as needed
    

  lifecycle {
    create_before_destroy = true
  }

  
}

# Auto Scaling Groups
resource "aws_autoscaling_group" "blue_asg" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  min_size     = 2
  max_size     = 4
  desired_capacity = 2
  vpc_zone_identifier = [aws_subnet.subnet_a.id]

  tag {
    key                 = "Name"
    value               = "blue-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "green_asg" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  min_size     = 2
  max_size     = 4
  desired_capacity = 0  # Start with zero instances
  vpc_zone_identifier = [aws_subnet.subnet_b.id]

  tag {
    key                 = "Name"
    value               = "green-app"
    propagate_at_launch = true
  }
}

# Application Load Balancers
resource "aws_lb" "blue_lb" {
  name               = "blue-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

resource "aws_lb" "green_lb" {
  name               = "green-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

# Target Groups
resource "aws_lb_target_group" "blue_tg" {
  name     = "blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group" "green_tg" {
  name     = "green-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Listener for Blue ALB
resource "aws_lb_listener" "blue_listener" {
  load_balancer_arn = aws_lb.blue_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue_tg.arn
  }
}

# Listener for Green ALB
resource "aws_lb_listener" "green_listener" {
  load_balancer_arn = aws_lb.green_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green_tg.arn
  }
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = "example.com"  # Update with your domain
}

# Route 53 Record for Blue Environment
resource "aws_route53_record" "blue_record" {
  zone_id = aws_route53_zone.main.zone_id
  name     = "app.laya.com"  
  type     = "A"

  alias {
    name                   = aws_lb.blue_lb.dns_name
    zone_id                = aws_lb.blue_lb.zone_id
    evaluate_target_health = false
  }
}

# Route 53 Record for Green Environment
resource "aws_route53_record" "green_record"

  zone_id = aws_route53_zone.main.zone_id
  name     = "green.app.yourdomain.com"  # Optional for testing
  type     = "A"

  alias {
    name                   = aws_lb.green_lb.dns_name
    zone_id                = aws_lb.green_lb.zone_id
    evaluate_target_health = false
  }
}

# Switch Traffic Btwn Blue/Green
resource "aws_lb_listener" "blue_url" {
 listener_arn = aws_lb_listener.http.arn
priority = 100


action{
 type           = "forward"
target_group_arn = aws_lb_target_group.blue.arn
}

condition {
 host_header {
  values = [ "app.laya.com"]
 }

}
