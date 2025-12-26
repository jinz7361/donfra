#!/bin/bash

API_BASE="http://localhost:8080/api"

echo "=== Test Lesson CRUD with Admin User ==="
echo

echo "1. Login as admin user"
curl -X POST $API_BASE/auth/login \
  -H "Content-Type: application/json" \
  -c /tmp/admin-cookies.txt \
  -d '{
    "email": "admin@donfra.com",
    "password": "admin123"
  }' 2>/dev/null | jq -r '.user.email, .user.role'
echo

echo "2. Create a test lesson (should succeed with Cookie)"
RESPONSE=$(curl -X POST $API_BASE/lessons \
  -H "Content-Type: application/json" \
  -b /tmp/admin-cookies.txt \
  -s -w "\n%{http_code}" \
  -d '{
    "slug": "auth-test-lesson",
    "title": "Auth Test Lesson",
    "markdown": "# Test",
    "excalidraw": {},
    "isPublished": true
  }')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
echo "HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Success: Lesson created with admin user JWT"
else
  echo "❌ Failed: $HTTP_CODE"
  echo "$RESPONSE" | head -n-1
fi
echo

echo "3. Logout admin user"
curl -X POST $API_BASE/auth/logout \
  -b /tmp/admin-cookies.txt \
  -s > /dev/null
echo "Logged out"
echo

echo "4. Try to create lesson without auth (should fail)"
HTTP_CODE=$(curl -X POST $API_BASE/lessons \
  -H "Content-Type: application/json" \
  -s -w "%{http_code}" -o /dev/null \
  -d '{
    "slug": "should-fail",
    "title": "Should Fail",
    "markdown": "# Test",
    "excalidraw": {},
    "isPublished": true
  }')
echo "HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "401" ]; then
  echo "✅ Correctly rejected: Unauthorized"
else
  echo "❌ Unexpected: $HTTP_CODE (expected 401)"
fi
echo

echo "5. Login as regular user"
curl -X POST $API_BASE/auth/register \
  -H "Content-Type: application/json" \
  -s -o /dev/null \
  -d '{
    "email": "regular@test.com",
    "password": "password123"
  }' 2>/dev/null
curl -X POST $API_BASE/auth/login \
  -H "Content-Type: application/json" \
  -c /tmp/user-cookies.txt \
  -s -o /dev/null \
  -d '{
    "email": "regular@test.com",
    "password": "password123"
  }'
echo "Logged in as regular user"
echo

echo "6. Try to create lesson as regular user (should fail)"
HTTP_CODE=$(curl -X POST $API_BASE/lessons \
  -H "Content-Type: application/json" \
  -b /tmp/user-cookies.txt \
  -s -w "%{http_code}" -o /dev/null \
  -d '{
    "slug": "should-also-fail",
    "title": "Should Also Fail",
    "markdown": "# Test",
    "excalidraw": {},
    "isPublished": true
  }')
echo "HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "401" ]; then
  echo "✅ Correctly rejected: Not an admin"
else
  echo "❌ Unexpected: $HTTP_CODE (expected 401)"
fi

echo
echo "=== Test Complete ==="
