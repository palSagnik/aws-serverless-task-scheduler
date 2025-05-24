# AWS Serverless Task Scheduler

A serverless task scheduling system built on AWS that allows you to schedule and execute tasks at specified times. The system uses AWS Lambda, DynamoDB, EventBridge Scheduler, and API Gateway to provide a scalable and cost-effective solution for task scheduling.

## Architecture

The system consists of the following components:

### 1. Task Scheduling API (Lambda Function)

- Handles incoming scheduling requests
- Validates and stores task details in DynamoDB
- Creates EventBridge schedules for task execution
- Exposed via API Gateway

### 2. Task Executor (Lambda Function)

- Executes scheduled tasks at the specified time
- Supports webhook actions (can be extended for other action types)
- Updates task status in DynamoDB

### 3. DynamoDB Table

- Stores task information including:
  - Task ID
  - Status (scheduled, running, completed, failed)
  - Action type
  - Payload
  - Schedule time
  - Creation and update timestamps

### 4. EventBridge Scheduler

- Manages task execution schedules
- Triggers the Task Executor Lambda at specified times

## Prerequisites

- AWS Account with appropriate permissions
- Terraform installed
- Node.js 18.x or later
- AWS CLI configured with appropriate credentials

## Setup

1. Clone the repository:

```bash
git clone <repository-url>
cd aws-serverless-task-scheduler
```

2. Initialize Terraform:

```bash
terraform init
```

3. Deploy the infrastructure:

```bash
terraform apply
```

4. Install dependencies and create Lambda deployment packages:

```bash
make lambda
```

## Usage

### Scheduling a Task

Send a POST request to the API endpoint with the following JSON structure:

```json
{
  "action": "webhook",
  "payload": {
    "url": "https://your-webhook-url.com",
    "data": {
      "message": "text"
    },
  },
  "runAt": "2024-03-20T15:00:00Z"
}
```

Example using curl:

```bash
curl -X POST https://your-api-gateway-url/init/schedule-task \
-H "Content-Type: application/json" \
-d '{
  "action": "webhook",
  "payload": {
    "url": "https://your-webhook-url.com",
    "data": {
      "message": "Hello World"
    }
  },
  "runAt": "2024-03-20T15:00:00Z"
}'
```

### Task Status

Tasks can have the following statuses:

- `scheduled`: Task is scheduled for execution
- `running`: Task is currently being executed
- `completed`: Task has been successfully executed
- `failed`: Task execution failed (check error message for details)

## Development

### Project Structure

```
.
├── lambdas/
│   ├── task-scheduling-api.js    # API handler for scheduling tasks
│   ├── task-executor.js          # Task execution handler
│   └── package.json             # Node.js dependencies
├── main.tf                      # Terraform infrastructure configuration
├── Makefile                     # Build and deployment commands
└── README.md                    # This file
```

### Available Make Commands

- `make lambda`: Create deployment packages for Lambda functions
- `make webhook`: Test the webhook functionality
- `make reset`: Destroy and recreate the infrastructure

## Security

The system implements several security measures:

- IAM roles with least privilege principle
- API Gateway with CORS configuration
- Secure task execution with proper error handling
- Input validation for all API requests


## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
