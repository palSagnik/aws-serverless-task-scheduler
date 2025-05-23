const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { v4: uuidv4 } = require('uuid');

// Initialize DynamoDB Client
const client = new DynamoDBClient({});
const dynamoDB = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
    try {
        const requestBody = JSON.parse(event.body);

        // Validate request
        if (!requestBody.action || !requestBody.payload || !requestBody.runAt) {
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'Missing required fields (action, payload, or runAt)' })
            };
        }

        // Generate task ID
        const taskId = uuidv4();
        const now = new Date().toISOString();

        // Store task in DynamoDB
        await dynamoDB.send(new PutCommand({
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
        }));

        return {
            statusCode: 201,
            body: JSON.stringify({ 
                taskId,
                message: 'Task scheduled successfully' 
            })
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ 
                message: 'Failed to schedule task',
                error: error.message 
            })
        };
    }
};
