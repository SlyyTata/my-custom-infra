variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "pub_subnet_cidr_block" {
  description = "The CIDR block for the public subnet"
  type        = string
}

variable "pub_subnet_cidr_block_2" {
  description = "The CIDR block for the second public subnet"
  type        = string
}

variable "priv_subnet_cidr_block_1" {
  description = "The CIDR block for the second private subnet"
  type        = string
}

variable "priv_subnet_cidr_block_2" {
  description = "The CIDR block for the third private subnet"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
}

variable "docker-image" {
  description = "The Docker image to use for the container"
  type        = string
}

variable "lb_name" {
  description = "The name of the application Load Balancer"
  type        = string
}


variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "The name of the ECS service"
  type        = string
}

variable "ecs_task_definition_name" {
  description = "The name of the ECS task definition"
  type        = string
}

variable "container_port" {
  description = "The port exposed on the container"
  type        = number
}

variable "certificate_arn" {
  description = "The ACM certificate arn"
  type        = string
}

variable "container_name" {
  description = "The name of the container"
  type        = string
}