# Terraform configuration for BIA application infrastructure
# Based on existing AWS infrastructure analysis

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ECR Repository
resource "aws_ecr_repository" "bia" {
  name                 = "bia"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "bia"
    Environment = var.environment
  }
}

# Security Groups
resource "aws_security_group" "bia_alb" {
  name        = "bia-alb"
  description = "Security group for BIA ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
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

  tags = {
    Name        = "bia-alb"
    Environment = var.environment
  }
}

resource "aws_security_group" "bia_ec2" {
  name        = "bia-ec2"
  description = "Security group for BIA ECS EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "acesso vindo de bia-alb"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.bia_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "bia-ec2"
    Environment = var.environment
  }
}

resource "aws_security_group" "bia_db" {
  name        = "bia-db"
  description = "Security group for BIA RDS database"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "acesso vindo de bia-ec2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bia_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "bia-db"
    Environment = var.environment
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "bia" {
  name       = "bia-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name        = "bia-subnet-group"
    Environment = var.environment
  }
}

# RDS Instance
resource "aws_db_instance" "bia" {
  identifier     = "bia"
  engine         = "postgres"
  engine_version = "17.4"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 1000
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.bia_db.id]
  db_subnet_group_name   = aws_db_subnet_group.bia.name

  backup_retention_period = 0
  backup_window          = "09:20-09:50"
  maintenance_window     = "mon:09:55-mon:10:25"

  skip_final_snapshot = true
  deletion_protection = false

  auto_minor_version_upgrade = true
  publicly_accessible       = false

  tags = {
    Name        = "bia"
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "bia" {
  name               = "bia-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.bia_alb.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false

  tags = {
    Name        = "bia-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "bia" {
  name     = "tg-bia"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/versao"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "tg-bia"
    Environment = var.environment
  }
}

# ALB Listener
resource "aws_lb_listener" "bia" {
  load_balancer_arn = aws_lb.bia.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bia.arn
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Instance
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

# Launch Template for ECS Instances
resource "aws_launch_template" "ecs" {
  name_prefix   = "bia-ecs-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.bia_ec2.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cluster_name = aws_ecs_cluster.bia.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "bia-ecs-instance"
      Environment = var.environment
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                = "bia-ecs-asg"
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.bia.arn]
  health_check_type   = "ELB"

  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "bia-ecs-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Data source for ECS optimized AMI
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "bia" {
  name = "bia-cluster-alb"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name        = "bia-cluster-alb"
    Environment = var.environment
  }
}

# Capacity Provider
resource "aws_ecs_capacity_provider" "bia" {
  name = "bia-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "bia" {
  cluster_name = aws_ecs_cluster.bia.name

  capacity_providers = [aws_ecs_capacity_provider.bia.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.bia.name
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "bia" {
  name              = "/ecs/bia-tf"
  retention_in_days = 7

  tags = {
    Name        = "bia-logs"
    Environment = var.environment
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "bia" {
  family                   = "bia-tf"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "bia"
      image     = "${aws_ecr_repository.bia.repository_url}:latest"
      cpu       = 1024
      memoryReservation = 410
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 0
          protocol      = "tcp"
          name          = "porta-80"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.bia.endpoint
        },
        {
          name  = "DB_PORT"
          value = "5432"
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "DB_PWD"
          value = var.db_password
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.bia.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  tags = {
    Name        = "bia-tf"
    Environment = var.environment
  }
}

# ECS Service
resource "aws_ecs_service" "bia" {
  name            = "bia-service"
  cluster         = aws_ecs_cluster.bia.id
  task_definition = aws_ecs_task_definition.bia.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.bia.arn
    container_name   = "bia"
    container_port   = 8080
  }

  placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 0
  }

  health_check_grace_period_seconds = 1

  depends_on = [
    aws_lb_listener.bia,
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
  ]

  tags = {
    Name        = "bia-service"
    Environment = var.environment
  }
}
