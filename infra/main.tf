
## DynamoDB Table
## TASK_SCHEDULER_TABLE
## taskId | status | 
resource "aws_dynamodb_table" "task_scheduler_table" {
  name           = "TaskSchedulerTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "taskId"

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

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "updatedAt"
    type = "S"
  }

  global_secondary_index {
    name = "StatusRunAtIndex"
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