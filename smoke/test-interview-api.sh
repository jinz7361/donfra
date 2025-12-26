#!/bin/bash

# Test script for Interview Room API
# Tests the new user-based interview room system

API_URL="http://localhost:8080/api"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Testing Interview Room API ===${NC}\n"

# Step 1: Register a new admin user
echo -e "${YELLOW}Step 1: Registering admin user...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST "$API_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin_user",
    "email": "admin@donfra.com",
    "password": "admin123",
    "role": "admin"
  }')

echo "Register response: $REGISTER_RESPONSE"

# Step 2: Login as admin user
echo -e "\n${YELLOW}Step 2: Logging in as admin user...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{
    "email": "admin@donfra.com",
    "password": "admin123"
  }')

echo "Login response: $LOGIN_RESPONSE"

USER_ID=$(echo $LOGIN_RESPONSE | jq -r '.user.id')
echo -e "${GREEN}✓ Logged in as admin user (ID: $USER_ID)${NC}"

# Step 3: Create interview room (only admin user can create)
echo -e "\n${YELLOW}Step 3: Creating interview room as admin...${NC}"
INIT_RESPONSE=$(curl -s -X POST "$API_URL/interview/init" \
  -H "Content-Type: application/json" \
  -b cookies.txt)

echo "Init response: $INIT_RESPONSE"

ROOM_ID=$(echo $INIT_RESPONSE | jq -r '.room_id')
INVITE_LINK=$(echo $INIT_RESPONSE | jq -r '.invite_link')
INVITE_TOKEN=$(echo $INVITE_LINK | sed 's/.*token=//')

if [ "$ROOM_ID" != "null" ] && [ ! -z "$ROOM_ID" ]; then
  echo -e "${GREEN}✓ Room created successfully${NC}"
  echo -e "  Room ID: $ROOM_ID"
  echo -e "  Invite Link: $INVITE_LINK"
else
  echo -e "${RED}✗ Failed to create room${NC}"
  exit 1
fi

# Step 4: Join room via invite token (as a guest user)
echo -e "\n${YELLOW}Step 4: Joining room via invite token...${NC}"
JOIN_RESPONSE=$(curl -s -X POST "$API_URL/interview/join" \
  -H "Content-Type: application/json" \
  -c guest_cookies.txt \
  -d "{
    \"invite_token\": \"$INVITE_TOKEN\"
  }")

echo "Join response: $JOIN_RESPONSE"

JOINED_ROOM_ID=$(echo $JOIN_RESPONSE | jq -r '.room_id')

if [ "$JOINED_ROOM_ID" == "$ROOM_ID" ]; then
  echo -e "${GREEN}✓ Successfully joined room${NC}"
else
  echo -e "${RED}✗ Failed to join room${NC}"
  exit 1
fi

# Step 5: Try to create another room (should fail - user already has active room)
echo -e "\n${YELLOW}Step 5: Trying to create another room (should fail)...${NC}"
DUPLICATE_RESPONSE=$(curl -s -X POST "$API_URL/interview/init" \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{}')

echo "Duplicate response: $DUPLICATE_RESPONSE"

if echo "$DUPLICATE_RESPONSE" | grep -q "already has an active room"; then
  echo -e "${GREEN}✓ Correctly prevented duplicate room creation${NC}"
else
  echo -e "${RED}✗ Should have prevented duplicate room${NC}"
fi

# Step 6: Close room as owner
echo -e "\n${YELLOW}Step 6: Closing room as owner...${NC}"
CLOSE_RESPONSE=$(curl -s -X POST "$API_URL/interview/close" \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d "{
    \"room_id\": \"$ROOM_ID\"
  }")

echo "Close response: $CLOSE_RESPONSE"

if echo "$CLOSE_RESPONSE" | grep -q "closed successfully"; then
  echo -e "${GREEN}✓ Room closed successfully${NC}"
else
  echo -e "${RED}✗ Failed to close room${NC}"
fi

# Step 7: Test regular user (should NOT be able to create room)
echo -e "\n${YELLOW}Step 7: Testing regular user room creation (should fail)...${NC}"

# Register regular user
echo "Registering regular user..."
REGULAR_REGISTER=$(curl -s -X POST "$API_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "regular_user",
    "email": "user@donfra.com",
    "password": "user123",
    "role": "user"
  }')

# Login as regular user
REGULAR_LOGIN=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -c regular_cookies.txt \
  -d '{
    "email": "user@donfra.com",
    "password": "user123"
  }')

echo "Regular user logged in"

# Try to create room (should fail - only admin can create)
echo "Trying to create room as regular user (should fail)..."
REGULAR_INIT_RESPONSE=$(curl -s -X POST "$API_URL/interview/init" \
  -H "Content-Type: application/json" \
  -b regular_cookies.txt)

echo "Regular user init response: $REGULAR_INIT_RESPONSE"

if echo "$REGULAR_INIT_RESPONSE" | grep -q "only admin users can create"; then
  echo -e "${GREEN}✓ Correctly prevented regular user from creating room${NC}"
else
  echo -e "${RED}✗ Should have prevented regular user from creating room${NC}"
fi

# Regular user can still join rooms via invite link
echo -e "\n${GREEN}Note: Regular users can join rooms using invite links${NC}"

# Cleanup
rm -f cookies.txt guest_cookies.txt regular_cookies.txt

echo -e "\n${GREEN}=== All tests completed ===${NC}"
