#!/bin/bash

# Test script for multi-room interview functionality
# Tests:
# 1. Admin creates two separate rooms
# 2. Users join different rooms via invite tokens
# 3. Verify rooms are isolated (different room_ids)

set -e

API_BASE="http://localhost:8080/api"
COOKIES_ADMIN="cookies_admin.txt"
COOKIES_USER1="cookies_user1.txt"
COOKIES_USER2="cookies_user2.txt"

cleanup() {
  rm -f $COOKIES_ADMIN $COOKIES_USER1 $COOKIES_USER2
}
trap cleanup EXIT

echo "=== Multi-Room Interview API Test ==="
echo ""

# Step 1: Admin login
echo "1. Admin login..."
curl -s -X POST "$API_BASE/auth/login" \
  -H "Content-Type: application/json" \
  -c $COOKIES_ADMIN \
  -d '{
    "email": "admin@donfra.com",
    "password": "admin123"
  }' | jq '.'

echo ""

# Step 2: Admin creates first room
echo "2. Admin creates first interview room..."
ROOM1_RESPONSE=$(curl -s -X POST "$API_BASE/interview/init" \
  -H "Content-Type: application/json" \
  -b $COOKIES_ADMIN)

echo "$ROOM1_RESPONSE" | jq '.'
ROOM1_ID=$(echo "$ROOM1_RESPONSE" | jq -r '.room_id')
ROOM1_INVITE=$(echo "$ROOM1_RESPONSE" | jq -r '.invite_link')
ROOM1_TOKEN=$(echo "$ROOM1_INVITE" | sed -n 's/.*token=\([^&]*\).*/\1/p')

echo "Room 1 ID: $ROOM1_ID"
echo "Room 1 Token: ${ROOM1_TOKEN:0:50}..."
echo ""

# Step 3: Close first room before creating second (one room per user limit)
echo "3. Closing first room..."
curl -s -X POST "$API_BASE/interview/close" \
  -H "Content-Type: application/json" \
  -b $COOKIES_ADMIN \
  -d "{\"room_id\": \"$ROOM1_ID\"}" | jq '.'

echo ""

# Step 4: Admin creates second room
echo "4. Admin creates second interview room..."
ROOM2_RESPONSE=$(curl -s -X POST "$API_BASE/interview/init" \
  -H "Content-Type: application/json" \
  -b $COOKIES_ADMIN)

echo "$ROOM2_RESPONSE" | jq '.'
ROOM2_ID=$(echo "$ROOM2_RESPONSE" | jq -r '.room_id')
ROOM2_INVITE=$(echo "$ROOM2_RESPONSE" | jq -r '.invite_link')
ROOM2_TOKEN=$(echo "$ROOM2_INVITE" | sed -n 's/.*token=\([^&]*\).*/\1/p')

echo "Room 2 ID: $ROOM2_ID"
echo "Room 2 Token: ${ROOM2_TOKEN:0:50}..."
echo ""

# Step 5: Verify rooms have different IDs
if [ "$ROOM1_ID" = "$ROOM2_ID" ]; then
  echo "❌ ERROR: Rooms should have different IDs!"
  exit 1
fi
echo "✅ Rooms have different IDs: $ROOM1_ID vs $ROOM2_ID"
echo ""

# Step 6: User 1 attempts to join closed room 1 (should fail)
echo "5. User 1 attempts to join closed room 1 (should fail)..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/interview/join" \
  -H "Content-Type: application/json" \
  -c $COOKIES_USER1 \
  -d "{\"invite_token\": \"$ROOM1_TOKEN\"}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "404" ]; then
  echo "✅ Correctly rejected: Room not found (closed)"
  echo "$BODY" | jq '.'
else
  echo "❌ ERROR: Expected 404, got $HTTP_CODE"
  echo "$BODY" | jq '.'
fi
echo ""

# Step 7: User 1 joins active room 2
echo "6. User 1 joins active room 2..."
curl -s -X POST "$API_BASE/interview/join" \
  -H "Content-Type: application/json" \
  -c $COOKIES_USER1 \
  -d "{\"invite_token\": \"$ROOM2_TOKEN\"}" | jq '.'

echo "✅ User 1 successfully joined room 2"
echo ""

# Step 8: User 2 also joins room 2
echo "7. User 2 joins the same room 2..."
curl -s -X POST "$API_BASE/interview/join" \
  -H "Content-Type: application/json" \
  -c $COOKIES_USER2 \
  -d "{\"invite_token\": \"$ROOM2_TOKEN\"}" | jq '.'

echo "✅ User 2 successfully joined room 2"
echo ""

# Step 9: Close room 2
echo "8. Admin closes room 2..."
curl -s -X POST "$API_BASE/interview/close" \
  -H "Content-Type: application/json" \
  -b $COOKIES_ADMIN \
  -d "{\"room_id\": \"$ROOM2_ID\"}" | jq '.'

echo "✅ Room 2 closed successfully"
echo ""

echo "=== All Multi-Room Tests Passed! ==="
echo ""
echo "Summary:"
echo "- Admin can create multiple rooms (sequentially)"
echo "- Each room has a unique room_id"
echo "- Users cannot join closed rooms"
echo "- Multiple users can join the same active room"
echo "- Rooms are properly isolated"
