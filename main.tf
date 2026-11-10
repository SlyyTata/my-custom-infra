#Setting up the custom VPC with the specified cidr block variable and creating 2 subnet within the VPC in 2 availability zones.

resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.vpc_name
  }
}


#Creating a public subnet where the ALB will resides
resource "aws_subnet" "pub_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.pub_subnet_cidr_block
  availability_zone = "${var.region}a"

  tags = {
    Name = "public-subnet1"
  }
}

resource "aws_subnet" "pub_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.pub_subnet_cidr_block_2
  availability_zone = "${var.region}b"

  tags = {
    Name = "public-subnet2"
  }
}

#Creating a private subnet where the ECSs will resides
resource "aws_subnet" "priv-subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.priv_subnet_cidr_block_1
  availability_zone = "${var.region}a"

  tags = {
    Name = "private-subnet1"
  }
}

#creating the 2nd subnet
resource "aws_subnet" "priv-subnet-2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.priv_subnet_cidr_block_2
  availability_zone = "${var.region}b"

  tags = {
    Name = "private-subnet2"
  }
}

#Adding an internet gateway to the VPC to allow communication between the VPC and the internet.
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "internet-gateway"
  }
}

#Adding anelastic IP so that the NAT gateway can be accessed from the internet.
resource "aws_eip" "my_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.my_igw]
}

#creating a NAT gateway in the public subnet to allow the ECSs in the private subnets to access the internet.
resource "aws_nat_gateway" "my_nat_gateway" {
  subnet_id     = aws_subnet.pub_subnet_1.id
  allocation_id = aws_eip.my_eip.id

  tags = {
    Name = "nat-gateway"
  }
}

#Creating a route table and associating it with the subnets to allow communication between the subnets and the internet gateway.
resource "aws_route_table" "pub_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

#Linking the route table to the public subnets to allow communication between the public subnet and the internet gateway.
resource "aws_route_table_association" "pub-subnet_association" {
  subnet_id      = aws_subnet.pub_subnet_1.id
  route_table_id = aws_route_table.pub_route_table.id
}

resource "aws_route_table_association" "pub-subnet-2_association" {
  subnet_id      = aws_subnet.pub_subnet_2.id
  route_table_id = aws_route_table.pub_route_table.id
}

#Creating a private route table for the private subnets
resource "aws_route_table" "priv_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private-route-table"
  }
}

#Adding a route to the private route table to allow communication between the private subnets and the NAT gateway.
resource "aws_route" "priv_route" {
  route_table_id         = aws_route_table.priv_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.my_nat_gateway.id  # NOTE 3
}

#Linking the private route table to the private subnets.
resource "aws_route_table_association" "priv-subnet_association" {
  subnet_id      = aws_subnet.priv-subnet.id
  route_table_id = aws_route_table.priv_route_table.id
}

resource "aws_route_table_association" "priv-subnet-2_association" {
  subnet_id      = aws_subnet.priv-subnet-2.id
  route_table_id = aws_route_table.priv_route_table.id
}

#Creating a security group to allow inbound traffic on port 80 and 443 for the ALB.
resource "aws_security_group" "my_security_group" {
  name        = "alb-security-group"
  description = "Allow inbound traffic on port 80 and 443"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
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

#Creating the ecs service security group to isolate the service
resource "aws_security_group" "service_sg" {
  name        = "svc-security-group"
  description = "Allow inbound traffic on port 8008"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    security_groups = [aws_security_group.my_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Creating an ECS task definition to run a containerized docker application on Fargate.
resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = var.ecs_task_definition_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = "public.ecr.aws/nginx/nginx:alpine"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
    }
  ])
  # Prevents Terraform from reverting the image tag to be created later.
  lifecycle {
    ignore_changes = [container_definitions]
  }
}

#Creating an ECS service to run the task definition on Fargate and associating it with the security group created above.
resource "aws_ecs_service" "my_ecs_service" {

  depends_on = [
    aws_ecs_task_definition.my_task_definition,
    aws_lb_target_group.ecs_tg
  ]

  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.my_ecs_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 90

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = var.container_name
    container_port   = var.container_port           
  }

  network_configuration {
    subnets         = [aws_subnet.priv-subnet.id, aws_subnet.priv-subnet-2.id]
    security_groups = [aws_security_group.service_sg.id]
    assign_public_ip = false
  }
  # Prevents Terraform from rolling your service back from future changes
  lifecycle {
    ignore_changes = [task_definition]
  }
}

#Creating an ECS cluster to run the ECS service on Fargate.
resource "aws_ecs_cluster" "my_ecs_cluster" {
  name = var.ecs_cluster_name
}

# 1. Application Load Balancer (ALB)
resource "aws_lb" "application_lb" {
  name               = var.lb_name
  internal           = false # Set to true if this is an internal-only load balancer
  load_balancer_type = "application"
  
  # The ALB must be placed in PUBLIC subnets to receive internet traffic
  subnets            = [aws_subnet.pub_subnet_1.id, aws_subnet.pub_subnet_2.id]
  security_groups    = [aws_security_group.my_security_group.id]

  tags = {
    Environment = "production"
  }
}

# 2. ALB Target Group
resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-fargate-tg"
  port        = var.container_port       
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  
  # CRUCIAL FOR FARGATE: Must be set to "ip"
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health" # Ensure your app actually serves this endpoint
    protocol            = "HTTP"
    port                = var.container_port
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 5
    matcher             = "200" # Expects an HTTP 200 OK response
  }
}

# 3. ALB Listener (Links the ALB to the Target Group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}
