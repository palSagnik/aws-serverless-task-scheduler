# DynamoDB Table
# TASK_SCHEDULER_TABLE
# taskId | status | action | payload | runAt | createdAt | updatedAt
resource "aws_dynamodb_table" "task_scheduler_table" {
  name         = "TaskSchedulerTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "taskId"

  attribute {
    name = "taskId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "runAt"
    type = "S"
  }

  global_secondary_index {
    name            = "StatusRunAtIndex"
    hash_key        = "status"
    range_key       = "runAt"
    projection_type = "ALL"
  }

  tags = {
    Application = "ServerlessTaskScheduler"
    Environment = "Production"
  }

}

output "dynamo_db_table_name" {
  value = aws_dynamodb_table.task_scheduler_table.name
}

# Lambda Function
# Task Scheduler
resource "aws_iam_role" "task_schedule_lambda_role" {
  name = "task_schedule_lambda_role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
        }
      ]
    }
  )
}

# Retrieve the current AWS region dynamically
data "aws_region" "current" {}

# Retrieve the current AWS account ID dynamically
data "aws_caller_identity" "current" {}

# Creation of IAM Policy for Lambda function to access dynamoDB
resource "aws_iam_policy" "dynamodb-task-schedule-role-policy" {
  name        = "dynamodb-task-schedule-role-policy"
  path        = "/"
  description = "AWS IAM Policy for Lambda to Access Dynamo DB and EventBridge Scheduler"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Resource" : "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "scheduler:CreateSchedule",
            "scheduler:DeleteSchedule",
            "scheduler:GetSchedule",
            "scheduler:UpdateSchedule"
          ],
          "Resource" : "arn:aws:scheduler:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:schedule/default/*"
        },
        {
          "Effect" : "Allow",
          "Action" : "iam:PassRole",
          "Resource" : aws_iam_role.eventbridge-scheduler-role.arn
        }
      ]
    }
  )
}

# IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "attach-task-schedule-policy-to-role" {
  role       = aws_iam_role.task_schedule_lambda_role.name
  policy_arn = aws_iam_policy.dynamodb-task-schedule-role-policy.arn
}

# Zip File
data "archive_file" "task-schedule-zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/"
  output_path = "${path.module}/lambdas/task-scheduling-func.zip"
}

# handler for lambda function
resource "aws_lambda_function" "task_scheduling_lambda_handler" {
  function_name = "task-scheduling-lambda-handler"

  filename   = "${path.module}/lambdas/task-scheduling-func.zip"
  role       = aws_iam_role.task_schedule_lambda_role.arn
  handler    = "task-scheduling-api.handler"
  runtime    = "nodejs18.x"
  depends_on = [aws_iam_role_policy_attachment.attach-task-schedule-policy-to-role]
  environment {
    variables = {
      TASK_TABLE_NAME = aws_dynamodb_table.task_scheduler_table.name

      # Task Executor Lambda Arn
      TASK_EXECUTOR_ARN = aws_lambda_function.task_executing_lambda_handler.arn

      # EventBridge scheduler role ARN
      SCHEDULER_ROLE_ARN = aws_iam_role.eventbridge-scheduler-role.arn
    }
  }
}

# API Gateway for lambda function handling
resource "aws_apigatewayv2_api" "task-schedule-api" {
  name          = "task-schedule-api"
  protocol_type = "HTTP"
  description   = "POST API to schedule tasks"

  cors_configuration {
    allow_credentials = false
    allow_headers     = []
    allow_origins = [
      "*",
    ]
    allow_methods = [
      "GET",
      "POST"
    ]
    max_age = 0
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "init" {
  api_id      = aws_apigatewayv2_api.task-schedule-api.id
  name        = "init"
  auto_deploy = true
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "task-schedule-api-integration" {
  api_id             = aws_apigatewayv2_api.task-schedule-api.id
  integration_uri    = aws_lambda_function.task_scheduling_lambda_handler.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# Routing queries from a public exposed url to lambda function
resource "aws_apigatewayv2_route" "task-schedule-api-route" {
  api_id    = aws_apigatewayv2_api.task-schedule-api.id
  route_key = "ANY /schedule-task"
  target    = "integrations/${aws_apigatewayv2_integration.task-schedule-api-integration.id}"
}

# Setting appropriate permission to invoke lambda function
resource "aws_lambda_permission" "api-gw-perms" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task_scheduling_lambda_handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.task-schedule-api.execution_arn}/*"
}

output "apigw-public-url" {
  value = "${aws_apigatewayv2_stage.init.invoke_url}/schedule-task"
}

# Lambda Function
# Task Executor
resource "aws_iam_policy" "dynamodb-task-execute-role-policy" {
  name        = "dynamodb-task-execute-role-policy"
  path        = "/"
  description = "AWS IAM Policy for Lambda to Access Dynamo DB"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:GetItem",
            "dynamodb:UpdateItem"
          ],
          "Resource" : "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        }
      ]
    }
  )
}

resource "aws_iam_role" "task_execute_lambda_role" {
  name = "task_execute_lambda_role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "lambda.amazonaws.com"
          },
        }
      ]
    }
  )
}

# IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "attach-task-execute-policy-to-role" {
  role       = aws_iam_role.task_execute_lambda_role.name
  policy_arn = aws_iam_policy.dynamodb-task-execute-role-policy.arn
}

# Zip File
data "archive_file" "task-execute-zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/"
  output_path = "${path.module}/lambdas/task-executor-func.zip"
}

# handler for lambda function
resource "aws_lambda_function" "task_executing_lambda_handler" {
  function_name = "task-executing-lambda-handler"

  filename   = "${path.module}/lambdas/task-executor-func.zip"
  role       = aws_iam_role.task_execute_lambda_role.arn
  handler    = "task-executor.handler"
  runtime    = "nodejs18.x"
  depends_on = [aws_iam_role_policy_attachment.attach-task-execute-policy-to-role]
  environment {
    variables = {
      TASK_TABLE_NAME = aws_dynamodb_table.task_scheduler_table.name
    }
  }
}

# EventBridge
# Scheduler
resource "aws_iam_role" "eventbridge-scheduler-role" {
  name = "eventbridge-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRole"
      Principal = {
        Service = "scheduler.amazonaws.com"
      },
    }]
  })
}

resource "aws_scheduler_schedule" "eventbridge_task_scheduler" {
  name       = "eventbridge_task_scheduler"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(5minutes)"

  target {
    arn      = aws_lambda_function.task_executing_lambda_handler.arn
    role_arn = aws_iam_role.eventbridge-scheduler-role.arn
  }
}

resource "aws_iam_role_policy" "eventbridge_scheduler_lambda" {
  name = "eventbridge-lambda-invoke"
  role = aws_iam_role.eventbridge-scheduler-role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["lambda:InvokeFunction"],
        Resource = aws_lambda_function.task_executing_lambda_handler.arn
      }
    ]
  })
}

output "scheduler_role_arn" {
  value = aws_iam_role.eventbridge-scheduler-role.arn
}

output "task_executor_arn" {
  value = aws_lambda_function.task_executing_lambda_handler.arn
}


