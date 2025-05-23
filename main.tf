
# DynamoDB Table
# TASK_SCHEDULER_TABLE
# taskId | status | action | runAt | createdAt | updatedAt
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

# Lambda
# Task Scheduler Lambda
resource "aws_iam_role" "lambda_role" {
  name = "aws-resume-lambda-role"

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
resource "aws_iam_policy" "dynamodb-lambda-role-policy" {
  name        = "dynamoDB-lambda-role-policy"
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
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Resource" : "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        }
      ]
    }
  )
}

# IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "attach-policy-to-role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb-lambda-role-policy.arn
}

# Zip File
data "archive_file" "zip-code" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/"
  output_path = "${path.module}/lambdas/task-scheduling-func.zip"
}

# handler for lambda function
resource "aws_lambda_function" "task-scheduling-lambda-handler" {
  function_name = "task-scheduling-lambda-handler"

  filename = "${path.module}/lambdas/task-scheduling-func.zip"
  role     = aws_iam_role.lambda_role.arn
  handler  = "lambda_function.lambda_handler"
  runtime = "ja"
  depends_on = [ aws_iam_role_policy_attachment.attach-policy-to-role ]
  environment {
    variables = {
      databaseName = TaskSchedulerTable
    }
  }
}

# API Gateway for lambda function handling
resource "aws_apigatewayv2_api" "task-schedule-api" {
  name          = ""
  protocol_type = HTTP
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
resource "aws_apigatewayv2_integration" "schedule-task-api-integration" {
  api_id             = aws_apigatewayv2_api.task-schedule-api.id
  integration_uri    = aws_lambda_function.task-scheduling-lambda-handler.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

# Routing queries from a public exposed url to lambda function
resource "aws_apigatewayv2_route" "schedule-task-api-route" {
  api_id = aws_apigatewayv2_api.schedule-task-api.id
  route_key = "ANY /schedule-task"
  target = "integrations/${aws_apigatewayv2_integration.schedule-task-api-integration.id}"
}

# Setting appropriate permission to invoke lambda function
resource "aws_lambda_permission" "api-gw-perms" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.task-scheduling-lambda-handler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.task-schedule-api.execution_arn}/*"
}

output "apigw-public-url" {
  value = "${aws_apigatewayv2_stage.init.invoke_url}/schedule-task"
}