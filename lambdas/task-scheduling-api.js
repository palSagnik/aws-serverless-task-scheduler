const AWS = require('aws-sdk')
const { v4:uuidv4 } = require('uuid')
const dynamoDB = AWS.DynamoDB.DocumentClient()
const scheduler = AWS.Scheduler()

/*
EXAMPLE REQUEST:
POST /schedule-task
Content-Type: application/json
{
    "action": "webhook",
    "payload": {
        "url": "https://example.com/notify",
        "data": { "message": "Hello, this is your scheduled task!" }
    },
    "run_at": "2024-06-10T15:00:00Z"
}
*/

exports.handler = async (event) => {
    try {
        const requestBody = JSON.parse(event.body)

        // validate request
        if (!requestBody.action || !requestBody.payload || !requestBody.runAt) {
            return {
                statusCode: 400,
                body: JSON.stringify({error: 'Missing required fields (action, payload or runAt'})
            }
        }

        // generate task ID
        const taskId = uuidv4()
        const now = new Date().toISOString()

        // store task in dynamoDB
        await dynamoDB.put({
            TableName: 'TaskSchedulerTable',
            Item: {
                taskId,
                status: 'scheduled',
                action: requestBody.action,
                payload: requestBody.payload,
                runAt: requestBody.runAt,
                createdAt: now,
                updatedAt: now,
            }
        }).promise()
    
        return {
            statusCode: 201,
            body: JSON.stringify({ 
              taskId,
              message: 'Task scheduled successfully' 
            })
          }
    }
    catch (error){
        return {
            statusCode: 500,
            body: JSON.stringify({ 
                message: 'Failed to schedule task',
                error: error 
            })
        }
    }
}