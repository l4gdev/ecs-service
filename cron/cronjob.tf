resource "aws_cloudwatch_event_rule" "rule" {
  name                = "${substr(var.application_config.environment, 0, 5)}-${var.application_config.name}-${var.cron_settings.name}"
  schedule_expression = var.cron_settings.schedule_expression
}

data "aws_ecs_cluster" "cluster" {
  cluster_name = var.ecs_settings.ecs_cluster_name
}


resource "aws_cloudwatch_event_target" "ecs_scheduled_task" {
  target_id = "${var.application_config.environment}-${var.cron_settings.name}"
  arn       = data.aws_ecs_cluster.cluster.arn
  rule      = aws_cloudwatch_event_rule.rule.name
  role_arn  = var.iam_role_arn

  ecs_target {
    task_count          = var.cron_settings.desired_count
    task_definition_arn = aws_ecs_task_definition.cron.arn
    propagate_tags      = "TASK_DEFINITION"
    tags = merge(var.tags, {
      Type         = "cron",
      Cron-Command = var.cron_settings.args
    })
    launch_type = var.launch_type
    dynamic "network_configuration" {
      for_each = var.launch_type == "FARGATE" ? [1] : []
      content {
        subnets          = var.subnets
        security_groups  = var.security_groups
        assign_public_ip = false
      }
    }
  }

  input = jsonencode(
    {
      containerOverrides = [
        {
          command = concat(try(var.cron_settings.execution_script, []), split(" ", var.cron_settings.args))
          name    = var.application_config.name
        }
      ]
    }
  )
}
