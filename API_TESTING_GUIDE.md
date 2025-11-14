# API Testing Guide - Conversation Lifecycle

This guide shows how to test the complete conversation lifecycle using only curl commands.

## Prerequisites

Start the API server:
```bash
cd /Users/guilhermecintra/dev/real-time-messaging
mix phx.server
```

## Quick Test (Automated Script)

Run the automated conversation test:
```bash
./test_conversation.sh
```

## Manual Testing (Step by Step)

### Setup Test IDs

```bash
# Set up test variables
CONVERSATION_ID="11111111-1111-1111-1111-111111111111"
ALICE_ID="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
BOB_ID="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
API_URL="http://localhost:4000/v1"
```

### 1. Alice sends first message

```bash
curl -X POST "$API_URL/messages" \
  -H 'Content-Type: application/json' \
  -d "{
    \"conversation_id\": \"$CONVERSATION_ID\",
    \"sender_id\": \"$ALICE_ID\",
    \"body\": {\"text\": \"Hello Bob!\"},
    \"idempotency_key\": \"alice-msg-1\"
  }" | jq .
```

**Expected Response:**
```json
{
  "message_id": "...",
  "status": "queued",
  "seq": 1,
  "conversation_id": "11111111-1111-1111-1111-111111111111",
  "inserted_at": "2025-11-14T..."
}
```

**Save the message_id:**
```bash
ALICE_MSG_1_ID="<paste-message-id-here>"
```

### 2. Bob sends reply

```bash
curl -X POST "$API_URL/messages" \
  -H 'Content-Type: application/json' \
  -d "{
    \"conversation_id\": \"$CONVERSATION_ID\",
    \"sender_id\": \"$BOB_ID\",
    \"body\": {\"text\": \"Hi Alice, how are you?\"},
    \"idempotency_key\": \"bob-msg-1\"
  }" | jq .
```

**Expected Response:**
```json
{
  "message_id": "...",
  "status": "queued",
  "seq": 2,
  "conversation_id": "11111111-1111-1111-1111-111111111111",
  "inserted_at": "2025-11-14T..."
}
```

**Save the message_id:**
```bash
BOB_MSG_1_ID="<paste-message-id-here>"
```

### 3. Alice sends another message

```bash
curl -X POST "$API_URL/messages" \
  -H 'Content-Type: application/json' \
  -d "{
    \"conversation_id\": \"$CONVERSATION_ID\",
    \"sender_id\": \"$ALICE_ID\",
    \"body\": {\"text\": \"I'm doing great, thanks! Want to grab coffee?\"},
    \"idempotency_key\": \"alice-msg-2\"
  }" | jq .
```

**Expected Response:**
```json
{
  "message_id": "...",
  "status": "queued",
  "seq": 3,
  "conversation_id": "11111111-1111-1111-1111-111111111111",
  "inserted_at": "2025-11-14T..."
}
```

**Save the message_id:**
```bash
ALICE_MSG_2_ID="<paste-message-id-here>"
```

### 4. List all messages in the conversation

```bash
curl "$API_URL/conversations/$CONVERSATION_ID/messages" | jq .
```

**Expected Response:**
```json
{
  "messages": [
    {
      "id": "...",
      "conversation_id": "11111111-1111-1111-1111-111111111111",
      "sender_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "seq": 1,
      "body": {"text": "Hello Bob!"},
      "status": "queued",
      "sent_at": null,
      "delivered_at": null,
      "read_at": null,
      "inserted_at": "..."
    },
    {
      "id": "...",
      "sender_id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "seq": 2,
      "body": {"text": "Hi Alice, how are you?"},
      "status": "queued",
      ...
    },
    ...
  ],
  "count": 3
}
```

### 5. Mark Alice's first message as delivered (Bob receives it)

```bash
curl -X POST "$API_URL/messages/$ALICE_MSG_1_ID/deliver" | jq .
```

**Expected Response:**
```json
{
  "message_id": "...",
  "status": "delivered",
  "delivered_at": "2025-11-14T..."
}
```

### 6. Bob marks Alice's first message as read

```bash
curl -X POST "$API_URL/messages/$ALICE_MSG_1_ID/read" | jq .
```

**Expected Response:**
```json
{
  "message_id": "...",
  "status": "read",
  "read_at": "2025-11-14T..."
}
```

### 7. Mark remaining messages as delivered and read

```bash
# Alice's second message
curl -X POST "$API_URL/messages/$ALICE_MSG_2_ID/deliver" | jq .
curl -X POST "$API_URL/messages/$ALICE_MSG_2_ID/read" | jq .

# Bob's message
curl -X POST "$API_URL/messages/$BOB_MSG_1_ID/deliver" | jq .
curl -X POST "$API_URL/messages/$BOB_MSG_1_ID/read" | jq .
```

### 8. View final conversation state

```bash
curl "$API_URL/conversations/$CONVERSATION_ID/messages" | jq '.messages[] | {seq, sender_id, text: .body.text, status, delivered_at, read_at}'
```

**Expected Response:**
```json
{
  "seq": 1,
  "sender_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "text": "Hello Bob!",
  "status": "read",
  "delivered_at": "2025-11-14T...",
  "read_at": "2025-11-14T..."
}
{
  "seq": 2,
  "sender_id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
  "text": "Hi Alice, how are you?",
  "status": "read",
  "delivered_at": "2025-11-14T...",
  "read_at": "2025-11-14T..."
}
{
  "seq": 3,
  "sender_id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "text": "I'm doing great, thanks! Want to grab coffee?",
  "status": "read",
  "delivered_at": "2025-11-14T...",
  "read_at": "2025-11-14T..."
}
```

## Features Demonstrated

✅ **Message Creation**
- Messages are created with `queued` status
- Each message gets an auto-incrementing sequence number
- Idempotency keys prevent duplicates

✅ **Conversation Listing**
- Messages ordered by sequence number
- All metadata visible (status, timestamps)

✅ **Status Transitions**
- queued → delivered → read
- Timestamps recorded for each transition

✅ **Ordering**
- Sequence numbers maintain conversation order
- Works regardless of when clients fetch messages

## Additional Test Cases

### Test Idempotency

Try sending the same message twice with the same idempotency key:
```bash
# First send
curl -X POST "$API_URL/messages" \
  -H 'Content-Type: application/json' \
  -d "{
    \"conversation_id\": \"$CONVERSATION_ID\",
    \"sender_id\": \"$ALICE_ID\",
    \"body\": {\"text\": \"Test idempotency\"},
    \"idempotency_key\": \"test-duplicate\"
  }"

# Second send (should fail)
curl -X POST "$API_URL/messages" \
  -H 'Content-Type: application/json' \
  -d "{
    \"conversation_id\": \"$CONVERSATION_ID\",
    \"sender_id\": \"$ALICE_ID\",
    \"body\": {\"text\": \"Test idempotency\"},
    \"idempotency_key\": \"test-duplicate\"
  }"
```

### Test Invalid Message ID

```bash
curl -X POST "$API_URL/messages/99999999-9999-9999-9999-999999999999/read" | jq .
```

**Expected:**
```json
{
  "error": "Message not found"
}
```

## API Endpoints Summary

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/v1/messages` | Create a new message |
| GET | `/v1/conversations/:id/messages` | List all messages in conversation |
| POST | `/v1/messages/:id/deliver` | Mark message as delivered |
| POST | `/v1/messages/:id/read` | Mark message as read |
| GET | `/healthz` | Health check |

## Notes

- In a real system, the `deliver` endpoint would be called by Oban workers, not clients
- WebSocket channels would broadcast status changes in real-time
- Authentication would restrict who can send/read messages
- The current implementation is for testing the basic CRUD and state machine

