resource "aws_iam_role" "ecs_events" {
  count = contains(["CRON"], var.ecs_settings.run_type) ? 1 : 0
  name_prefix  = "${var.application_config.environment}-${var.application_config.name}"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "events.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "ecs_events_run_task_with_any_role" {
  count = contains(["CRON"], var.ecs_settings.run_type) && length(module.cron) > 0 ? 1 : 0

  name = "${var.application_config.environment}-${var.application_config.name}"
  role = aws_iam_role.ecs_events[0].id

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "iam:PassRole",
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : "ecs:RunTask",
          "Resource" : [for _, v in module.cron : replace(v.task_definition.arn, "/:\\d+$/", ":*")]
        }
      ]
  })
}

module "cron" {
  source   = "./cron/"
  for_each = { for cron in try(var.cron.settings, []) : replace(cron.name, ":", "-") => cron }

  application_config            = var.application_config
  cron_settings                 = merge(each.value, { execution_script = var.cron.execution_script })
  ecs_settings                  = var.ecs_settings
  iam_role_arn                  = aws_iam_role.ecs_events[0].arn
  tags                          = local.tags
  launch_type                   = var.ecs_settings.ecs_launch_type
  subnets                       = var.subnets
  security_groups               = var.security_groups
  ecs_execution_arn             = aws_iam_role.ecs_task_execution_role.arn
  network_mode                  = var.network_mode
  running_container_definitions = local.running_container_definitions
  task_role_service_arn         = aws_iam_role.service_role.arn
  volumes                       = var.volumes
}
