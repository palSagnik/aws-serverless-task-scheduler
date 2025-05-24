const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require("@aws-sdk/lib-dynamodb");
const axios = require("axios");

const ddbClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(ddbClient);

const TASK_TABLE_NAME = process.env.TASK_TABLE_NAME;

// Helper Functions
const getTaskDetails = async (taskId) => {
  const { Item: task } = await docClient.send(
    new GetCommand({
      TableName: TASK_TABLE_NAME,
      Key: { taskId },
    })
  );

  if (!task) throw new Error(`Task with taskId-${taskId} not found.`);
  return task
};

const updateTaskStatus = async (taskId, taskStatus, errorMessage = null) => {
    const updateParams = {
        TableName: TASK_TABLE_NAME,
        Key: { taskId },
        UpdateExpression: "SET #status = :status, updatedAt = :now",
        ExpressionAttributeNames: { "#status": "status" },
        ExpressionAttributeValues: {
          ":status": taskStatus,
          ":now": new Date().toISOString()
        }
      };
    
      if (errorMessage) {
        updateParams.UpdateExpression += ", errorMessage = :error";
        updateParams.ExpressionAttributeValues[":error"] = errorMessage;
      }
    
      await docClient.send(new UpdateCommand(updateParams));
}

const executeWebhook = async (task) => {
    if (!task.payload?.url) {
      throw new Error("Webhook URL missing in payload");
    }
  
    const response = await axios({
      method: "POST",
      url: task.payload.url,
      data: task.payload.data || {},
      headers: task.payload.headers || {}
    });
  
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`Webhook failed with status ${response.status}`);
    }
};

exports.handler = async (event) => {
  const { taskId } = event;
  if (!taskId) {
    console.error("No TaskId provided in event");
    return;
  }

  try {
    // Fetch Task from DynamoDB
    const task = await getTaskDetails(taskId)
    
    // Update taskStatus to running
    await updateTaskStatus(taskId, "running");

    // Execute action
    switch (task.action) {
        case "webhook":
            await executeWebhook(task);
            break;
        default:
            throw new Error(`Unsupported action type: ${task.action}`);
    }

    // Update taskStatus to completed
    await updateTaskStatus(taskId, "completed")

  } catch (error) {
    console.error(`Task execution failed: ${error.message}`);
    await updateTaskStatus(taskId, "failed", error.message);
  }
};
