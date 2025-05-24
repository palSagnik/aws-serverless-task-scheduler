#!/bin/sh

# POST
curl -X POST https://sn1ikr93u0.execute-api.us-east-1.amazonaws.com/init/schedule-task \
-H "Content-Type: application/json" \
-d '{
    "action": "webhook",
    "payload": {
        "url": "https://example.com/notify",
        "data": { "message": "Hello, this is your scheduled task!" }
    },
    "runAt": "2024-07-10T15:00:00Z"
}'
