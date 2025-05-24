#!/bin/sh

# POST
curl -X POST https://jdssaypru2.execute-api.us-east-1.amazonaws.com/init/schedule-task \
-H "Content-Type: application/json" \
-d '{
    "action": "webhook",
    "payload": {
        "url": "https://webhook.site/2f3e492a-7948-46d2-80b3-71d5873ee9a1",
        "data": { "message": "Hello, this is your scheduled task! AND WORKING FINE" }
    },
    "runAt": "2025-05-24T17:16:00Z"
}'
