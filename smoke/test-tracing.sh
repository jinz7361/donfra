#!/bin/bash

# Jaeger Tracing Test Script
# This script generates various API requests to create traces in Jaeger

API_URL="${API_URL:-http://localhost:8080}"
ADMIN_TOKEN=""

echo "🚀 Jaeger Tracing Test Script"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print section headers
section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to make a request and show result
request() {
    local method=$1
    local path=$2
    local data=$3
    local headers=$4

    echo -e "${YELLOW}→ $method $path${NC}"

    if [ -n "$data" ]; then
        if [ -n "$headers" ]; then
            curl -s -X $method "$API_URL$path" \
                -H "Content-Type: application/json" \
                -H "$headers" \
                -d "$data" | jq -C '.' 2>/dev/null || echo "(response not JSON)"
        else
            curl -s -X $method "$API_URL$path" \
                -H "Content-Type: application/json" \
                -d "$data" | jq -C '.' 2>/dev/null || echo "(response not JSON)"
        fi
    else
        if [ -n "$headers" ]; then
            curl -s -X $method "$API_URL$path" \
                -H "$headers" | jq -C '.' 2>/dev/null || echo "(response not JSON)"
        else
            curl -s "$API_URL$path" | jq -C '.' 2>/dev/null || echo "(response not JSON)"
        fi
    fi

    sleep 0.5
}

# 1. Health Check (always succeeds - good baseline trace)
section "1️⃣  Health Check (Fast & Simple Trace)"
request GET "/healthz"
echo -e "${GREEN}✓ This creates a simple trace with minimal spans${NC}"

# 2. Get all lessons (database query trace)
section "2️⃣  List All Lessons (Database Query Trace)"
request GET "/api/lessons"
echo -e "${GREEN}✓ This shows database query timing in the trace${NC}"

# 3. Get specific lesson (with slug parameter)
section "3️⃣  Get Specific Lesson (Parameterized Route)"
request GET "/api/lessons/intro-to-go"
echo -e "${GREEN}✓ You'll see the slug parameter in the span${NC}"

# 4. Admin login (get token for protected routes)
section "4️⃣  Admin Login (Authentication Flow)"
echo "Logging in as admin..."
RESPONSE=$(curl -s -X POST "$API_URL/api/admin/login" \
    -H "Content-Type: application/json" \
    -d '{"password":"7777"}')

ADMIN_TOKEN=$(echo $RESPONSE | jq -r '.token' 2>/dev/null)

if [ "$ADMIN_TOKEN" != "null" ] && [ -n "$ADMIN_TOKEN" ]; then
    echo -e "${GREEN}✓ Got admin token: ${ADMIN_TOKEN:0:20}...${NC}"
else
    echo -e "${RED}✗ Failed to get admin token${NC}"
    echo "Response: $RESPONSE"
fi

# 5. Create a lesson (admin-protected route)
section "5️⃣  Create Lesson (Admin Protected Route)"
if [ -n "$ADMIN_TOKEN" ]; then
    request POST "/api/lessons" \
        '{
            "slug": "jaeger-test",
            "title": "Testing Jaeger Tracing",
            "markdown": "# Jaeger Test\n\nThis lesson was created to test tracing.",
            "excalidraw": {},
            "isPublished": true
        }' \
        "Authorization: Bearer $ADMIN_TOKEN"
    echo -e "${GREEN}✓ This trace shows authentication middleware in action${NC}"
else
    echo -e "${RED}✗ Skipped (no admin token)${NC}"
fi

# 6. Update a lesson (PATCH request)
section "6️⃣  Update Lesson (PATCH Request)"
if [ -n "$ADMIN_TOKEN" ]; then
    request PATCH "/api/lessons/jaeger-test" \
        '{
            "title": "Updated: Jaeger Tracing Demo",
            "markdown": "# Updated\n\nThis was updated via API."
        }' \
        "Authorization: Bearer $ADMIN_TOKEN"
    echo -e "${GREEN}✓ Compare this trace with the create trace${NC}"
else
    echo -e "${RED}✗ Skipped (no admin token)${NC}"
fi

# 7. Unauthorized access (error trace)
section "7️⃣  Unauthorized Access (Error Trace)"
request POST "/api/lessons" \
    '{
        "slug": "should-fail",
        "title": "This should fail"
    }'
echo -e "${GREEN}✓ This creates an error trace (401 Unauthorized)${NC}"

# 8. Not found (404 error trace)
section "8️⃣  Not Found (404 Error Trace)"
request GET "/api/lessons/does-not-exist"
echo -e "${GREEN}✓ This creates a 404 error trace${NC}"

# 9. Room status check
section "9️⃣  Room Status (Different Service Domain)"
request GET "/api/room/status"
echo -e "${GREEN}✓ This shows a different code path in traces${NC}"

# 10. Concurrent requests (to show distributed tracing)
section "🔟 Concurrent Requests (Load Test)"
echo "Sending 10 concurrent requests..."
for i in {1..10}; do
    curl -s "$API_URL/api/lessons" > /dev/null &
done
wait
echo -e "${GREEN}✓ Check Jaeger to see multiple traces at the same time${NC}"

# Summary
section "📊 Summary"
echo "All test requests completed!"
echo ""
echo -e "${GREEN}Now open Jaeger UI:${NC}"
echo -e "  ${BLUE}http://localhost:16686${NC}"
echo ""
echo -e "${YELLOW}What to look for:${NC}"
echo "  1. Select Service: 'donfra-api'"
echo "  2. Click 'Find Traces'"
echo "  3. You should see ~20+ traces from the last minute"
echo "  4. Click on any trace to see detailed timing"
echo ""
echo -e "${YELLOW}Try these filters:${NC}"
echo "  • Tags: http.status_code=200 (successful requests)"
echo "  • Tags: http.status_code=401 (auth failures)"
echo "  • Tags: http.method=POST (only POST requests)"
echo "  • Min Duration: 100ms (slow requests only)"
echo ""
echo -e "${GREEN}Happy tracing! 🎯${NC}"
