output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.my_ecs_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.my_ecs_service.name
}

output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.my_task_definition.arn
}

output "application_load_balancer" {
  value = aws_lb.application_lb.name
}

output "container_port" {
  value = var.container_port
}