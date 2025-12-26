# Multi-Room Yjs Integration

## Overview

The Donfra platform now supports **multiple isolated collaborative rooms**, each with its own Yjs document for real-time editing. This enables:

- **Admin users** can create multiple interview rooms with unique `room_id`
- **Each room has its own isolated Yjs document** - edits in one room don't affect others
- **Regular users join rooms via invite links** containing JWT tokens
- **WebSocket server manages multiple Yjs documents** keyed by `room_id`

## Architecture

### 1. Backend (donfra-api)

The API manages interview rooms with PostgreSQL persistence:

**Database Schema**: [interview_rooms](../infra/db/migrations/002_create_interview_rooms.sql)
```sql
CREATE TABLE interview_rooms (
    id SERIAL PRIMARY KEY,
    room_id VARCHAR(255) UNIQUE NOT NULL,
    owner_id INTEGER NOT NULL REFERENCES users(id),
    headcount INTEGER DEFAULT 0,
    code_snapshot TEXT DEFAULT '',
    invite_link VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);
```

**API Endpoints**:
- `POST /api/interview/init` - Admin creates room, returns `room_id` and `invite_link`
- `POST /api/interview/join` - User joins via `invite_token`, receives `room_access` cookie
- `POST /api/interview/close` - Owner closes room (soft delete)

See [INTERVIEW_ROOM_API.md](./INTERVIEW_ROOM_API.md) for full API documentation.

### 2. WebSocket Server (donfra-ws)

The WebSocket server manages multiple Yjs documents:

**File**: [donfra-ws/ws-server.js](../donfra-ws/ws-server.js)

**Key Changes**:
```javascript
wss.on('connection', (conn, req) => {
  // Extract room_id from URL path (y-websocket sends room name in path)
  // URL format: /room-id
  const docName = req.url.slice(1).split('?')[0] || 'default-room'

  console.log(`New WS connection to room: ${docName}`)

  // setupWSConnection creates/retrieves Yjs document by docName
  // Each unique docName gets its own isolated Yjs document
  setupWSConnection(conn, req, {
    gc: docName !== 'ws/prosemirror-versions'
  })
})
```

**Document Isolation**: The y-websocket library maintains a `Map<string, WSSharedDoc>` where:
- **Key**: `room_id` (from URL path)
- **Value**: Isolated Yjs document with its own state and connections

**Monitoring**:
```javascript
// Monitor connection count per room
setInterval(() => {
  const roomStats = {}
  docs.forEach((doc, docName) => {
    const roomConns = doc.conns.size
    if (roomConns > 0) {
      roomStats[docName] = roomConns
    }
  })
  console.log(`Stats: ${JSON.stringify({ rooms: roomStats })}`)
}, 3000)
```

### 3. Frontend (donfra-ui)

#### New `/interview` Page

**File**: [donfra-ui/app/interview/page.tsx](../donfra-ui/app/interview/page.tsx)

**Flow**:
1. Extract `token` from URL query parameter: `/interview?token=eyJ...`
2. Call `POST /api/interview/join` with the token
3. Receive `room_id` and `room_access` cookie
4. Render `<CodePad roomId={room_id} />` for collaborative editing

**Code**:
```typescript
export default function InterviewPage() {
  const [roomId, setRoomId] = useState<string>("");

  useEffect(() => {
    const joinRoom = async () => {
      const token = searchParams.get("token");

      const response = await fetch("/api/interview/join", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ invite_token: token }),
        credentials: "include", // Important for cookies
      });

      const data = await response.json();
      setRoomId(data.room_id); // e.g., "3f7a2c8b1e9d4f6a..."
    };

    joinRoom();
  }, [searchParams]);

  return <CodePad onExit={handleExit} roomId={roomId} />;
}
```

**User Authentication Integration**:

The `/interview` page sets the `auth_token` cookie when users join via invite link. This cookie is then used by the CodePad component to fetch the user's real username.

#### Updated `CodePad` Component

**File**: [donfra-ui/components/CodePad.tsx](../donfra-ui/components/CodePad.tsx)

**Props**:
```typescript
type Props = {
  onExit?: () => void;
  roomId?: string; // NEW: room_id from interview API
};
```

**Yjs Connection**:
```typescript
// Use roomId prop if provided (for interview rooms),
// otherwise fall back to URL param or default
const roomName = roomId || params.get("invite") || "default-room";

// WebSocket URL
const collabURL = process.env.NEXT_PUBLIC_COLLAB_WS ??
  `${window.location.protocol === "https:" ? "wss" : "ws"}://${window.location.host}/yjs`;

// WebsocketProvider sends roomName in URL path
// Server creates isolated Yjs document per roomName
const provider = new YWebsocketNS.WebsocketProvider(
  collabURL,    // e.g., ws://localhost:3000/yjs
  roomName,     // e.g., "3f7a2c8b1e9d4f6a..." (appended to path)
  doc,
  { connect: true }
);
```

**Real Username Display**:
```typescript
// Get real username from backend (if user is authenticated)
let userName = `User-${Math.random().toString(36).slice(2, 6)}`;
try {
  const response = await fetch("/api/auth/me", {
    method: "GET",
    credentials: "include",
  });
  if (response.ok) {
    const data = await response.json();
    if (data.user && data.user.username) {
      userName = data.user.username; // Use real username
    }
  }
} catch (err) {
  // If not authenticated, use guest username
  console.log("Not authenticated, using guest username");
}

// Set username in Yjs awareness so others can see it
awareness.setLocalState({
  user: {
    name: userName,
    color: `hsl(${Math.floor(Math.random() * 360)} 70% 55%)`,
    colorLight: `hsl(${Math.floor(Math.random() * 360)} 70% 55% / .22)`
  }
});
```

**How it Works**:
- `WebsocketProvider` sends WebSocket connection to: `ws://host/yjs/3f7a2c8b1e9d4f6a...`
- Server extracts `3f7a2c8b1e9d4f6a...` from URL path
- Server retrieves or creates Yjs document with that key
- All clients connecting to the same `room_id` share the same Yjs document

## Real Username Display

### How It Works

When a user enters a collaborative room (either via `/coding` or `/interview`), the CodePad component:

1. **Fetches user information** from `/api/auth/me` using the `auth_token` cookie
2. **Extracts the real username** from the response (e.g., "alice", "bob")
3. **Sets the username in Yjs awareness** so other participants can see it
4. **Falls back to guest username** if user is not authenticated (e.g., "User-a3b7")

### Authentication Flow

```
User joins room → CodePad mounts
                      ↓
                  fetch("/api/auth/me", { credentials: "include" })
                      ↓
            Backend validates auth_token cookie
                      ↓
            Returns: { user: { username: "alice", ... } }
                      ↓
            CodePad sets awareness: { user: { name: "alice", color, colorLight } }
                      ↓
            ✅ Other users in the room see "alice" as the username
```

### Benefits

- **No hardcoded usernames**: No longer relies on URL parameters like `?role=master`
- **Real user identity**: Shows actual usernames from the user database
- **Guest support**: Unauthenticated users still get a random guest username
- **Consistent experience**: Same username appears in cursor labels and peer list
- **Distinct visual identity**: Each user gets a unique color for their cursor and selections

## Visual Differentiation

### Color Palette

Each user is assigned a distinct color from a predefined palette of 10 vibrant colors:

```typescript
const colorPalette = [
  { color: "#e74c3c", colorLight: "rgba(231, 76, 60, 0.25)" },   // Red
  { color: "#3498db", colorLight: "rgba(52, 152, 219, 0.25)" },  // Blue
  { color: "#2ecc71", colorLight: "rgba(46, 204, 113, 0.25)" },  // Green
  { color: "#f39c12", colorLight: "rgba(243, 156, 18, 0.25)" },  // Orange
  { color: "#9b59b6", colorLight: "rgba(155, 89, 182, 0.25)" },  // Purple
  { color: "#1abc9c", colorLight: "rgba(26, 188, 156, 0.25)" },  // Turquoise
  { color: "#e91e63", colorLight: "rgba(233, 30, 99, 0.25)" },   // Pink
  { color: "#00bcd4", colorLight: "rgba(0, 188, 212, 0.25)" },   // Cyan
  { color: "#ff5722", colorLight: "rgba(255, 87, 34, 0.25)" },   // Deep Orange
  { color: "#8bc34a", colorLight: "rgba(139, 195, 74, 0.25)" },  // Light Green
];
```

### Visual Features

**Cursor Styling**:
- **3px solid border** on the left side in the user's color
- **Blinking animation** (1s cycle) for better visibility
- **High z-index** to ensure cursors are always visible

**Selection Highlighting**:
- **Semi-transparent background** (25% opacity) in the user's color
- **1px border** for clear boundaries
- **Normal blend mode** to prevent color distortion

**Username Labels**:
- **Background color** matches the user's color
- **White text** with bold font weight (600)
- **Larger font size** (12px) for better readability
- **Padding and border radius** for a polished look
- **Drop shadow** for depth and visibility
- **Positioned above cursor** with slight vertical offset

### Example Visual Output

```
User A (Red - alice):
├─ Cursor: 3px red border, blinking
├─ Selection: Light red background with red border
└─ Label: Red background with "alice" in white

User B (Blue - bob):
├─ Cursor: 3px blue border, blinking
├─ Selection: Light blue background with blue border
└─ Label: Blue background with "bob" in white

User C (Green - guest):
├─ Cursor: 3px green border, blinking
├─ Selection: Light green background with green border
└─ Label: Green background with "User-a3b7" in white
```

### Example

```typescript
// Before (old implementation):
// URL: /coding?role=master
// Username: "Master" (hardcoded based on URL param)

// After (new implementation):
// User authenticated as "alice"
// Username: "alice" (fetched from /api/auth/me)

// Guest user (not authenticated):
// Username: "User-a3b7" (random fallback)
```

## User Flows

### Admin Creates Room

```bash
# 1. Login as admin
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -c cookies.txt \
  -d '{"email": "admin@donfra.com", "password": "admin123"}'

# 2. Create interview room
curl -X POST http://localhost:8080/api/interview/init \
  -H "Content-Type: application/json" \
  -b cookies.txt

# Response:
# {
#   "room_id": "3f7a2c8b1e9d4f6a0c5b8e7d2a1f4c9b",
#   "invite_link": "http://localhost:3000/interview?token=eyJhbGc...",
#   "message": "Interview room created successfully"
# }

# 3. Share invite link with participants
```

### Regular User Joins Room

```bash
# User receives invite link:
# http://localhost:3000/interview?token=eyJhbGc...

# 1. User opens link in browser
# 2. Frontend extracts token from URL
# 3. Frontend calls POST /api/interview/join with token
# 4. Backend validates token, returns room_id, sets room_access cookie
# 5. Frontend connects to Yjs WebSocket with room_id
# 6. User can now collaborate in real-time with others in the same room
```

### Collaborative Editing

When multiple users are in the same room:

1. **User A** joins room `abc123` and types code
2. **User B** joins room `abc123` via invite link
3. **Both see each other's cursors and edits in real-time** (Yjs CRDT sync)
4. **User C** joins a different room `xyz789`
5. **User C's edits are isolated** - they don't see or affect room `abc123`

### WebSocket Connection Flow

```
User Browser → WebSocket Connection
  |
  ├─ URL: ws://localhost:3000/yjs/abc123
  |
  └─ Server extracts docName: "abc123"
     |
     └─ Retrieves/creates Yjs document for "abc123"
        |
        ├─ User A in "abc123" → shares same Yjs doc
        ├─ User B in "abc123" → shares same Yjs doc
        └─ User C in "xyz789" → isolated Yjs doc
```

## Environment Variables

### donfra-api

```bash
JWT_SECRET=your-secret-key     # Used to sign invite tokens
BASE_URL=http://localhost:3000 # Frontend URL for generating invite links
DATABASE_URL=postgres://...    # PostgreSQL connection
```

### donfra-ui

```bash
# WebSocket endpoint for Yjs collaboration
NEXT_PUBLIC_COLLAB_WS=/yjs

# API proxy targets (for Docker/production)
API_PROXY_TARGET=http://api:8080
WS_PROXY_TARGET=http://ws:6789
```

### donfra-ws

```bash
PORT=6789                      # WebSocket server port
PRODUCTION=true                # Enable production optimizations
REDIS_ADDR=localhost:6379      # Redis for pub/sub (optional)
```

## Testing

### Smoke Tests

**File**: [smoke/test-multi-room.sh](../smoke/test-multi-room.sh)

```bash
cd /home/don/donfra
./smoke/test-multi-room.sh
```

**Tests**:
1. Admin creates two rooms sequentially (one active at a time)
2. Verifies rooms have different `room_id`
3. User cannot join closed rooms (404 error)
4. Multiple users can join the same active room
5. Rooms are properly isolated

### Manual Testing

**Test 1: Single Room**
```bash
# Terminal 1: Start services
make localdev-up

# Terminal 2: Admin creates room
./smoke/test-interview-api.sh

# Browser 1: Admin opens invite link
# Browser 2: User opens same invite link
# → Both should see each other's cursors and edits in real-time
```

**Test 2: Multiple Rooms**
```bash
# Terminal 1: Admin creates room 1
curl -X POST http://localhost:8080/api/interview/init -b cookies.txt

# Copy invite_link_1

# Terminal 2: Admin closes room 1, creates room 2
curl -X POST http://localhost:8080/api/interview/close -b cookies.txt -d '{"room_id": "..."}'
curl -X POST http://localhost:8080/api/interview/init -b cookies.txt

# Copy invite_link_2

# Browser 1: Open invite_link_2
# Browser 2: Open invite_link_2
# Browser 3: Try to open invite_link_1 (should show error: room closed)
# → Browsers 1 & 2 should collaborate, Browser 3 should be rejected
```

## Key Implementation Details

### 1. Room Isolation

Each `room_id` maps to a unique Yjs document in the WebSocket server's memory:

```javascript
// y-websocket library internally maintains:
const docs = new Map<string, WSSharedDoc>();

// When user connects to /yjs/abc123:
const doc = docs.get("abc123") || createNewDoc("abc123");
```

### 2. Invite Token Structure

JWT token claims:
```json
{
  "room_id": "3f7a2c8b1e9d4f6a0c5b8e7d2a1f4c9b",
  "sub": "interview_room",
  "exp": 1234567890,  // 24 hours from creation
  "iss": "donfra-api"
}
```

### 3. Cookie-Based Access

- **`auth_token`**: User authentication (7 days, set by `/api/auth/login`)
  - Contains: `user_id`, `email`, `role`
  - Used by: Admin operations (create/close room)

- **`room_access`**: Room access (24 hours, set by `/api/interview/join`)
  - Contains: `room_id` (plaintext, not signed)
  - Used by: Future room-restricted operations (e.g., code execution)

### 4. Soft Delete Pattern

Rooms are never physically deleted:
```sql
-- Close room (sets deleted_at)
UPDATE interview_rooms
SET deleted_at = CURRENT_TIMESTAMP
WHERE room_id = $1;

-- Query only active rooms
SELECT * FROM interview_rooms
WHERE deleted_at IS NULL;
```

## Troubleshooting

### Issue: Users in same room don't see edits

**Check**:
1. Both users have the same `room_id`
2. WebSocket connection is established (`Network` tab in DevTools)
3. Console shows `New WS connection to room: <room_id>`

**Fix**: Ensure `roomId` prop is passed correctly to `CodePad`

### Issue: WebSocket connection fails

**Check**:
1. `donfra-ws` service is running
2. Proxy configuration in `next.config.mjs` routes `/yjs/*` to WebSocket server
3. CORS headers allow WebSocket upgrades

**Fix**: Check `docker-compose` logs for `donfra-ws` errors

### Issue: Invite token expired

**Symptom**: 401 error when joining room

**Reason**: Tokens expire after 24 hours

**Fix**: Admin re-generates invite link by re-creating the room

## Future Enhancements

### 1. Persistence

Currently, Yjs documents are in-memory only. To persist collaborative state:

```bash
# Enable y-leveldb persistence
cd donfra-ws
npm install y-leveldb
export YPERSISTENCE=/data/yjs-persist
```

### 2. Room Headcount Updates

Update `interview_rooms.headcount` when users join/leave:

```javascript
// In ws-server.js
docs.forEach((doc, docName) => {
  const headcount = doc.conns.size;
  // POST to /api/interview/headcount
  fetch(`${API_URL}/interview/headcount`, {
    method: 'POST',
    body: JSON.stringify({ room_id: docName, headcount })
  });
});
```

### 3. Room Snapshots

Save final code when room closes:

```javascript
// Before soft-deleting room
const code = ydoc.getText('monaco').toString();
UPDATE interview_rooms
SET code_snapshot = $1, deleted_at = NOW()
WHERE room_id = $2;
```

## Related Documentation

- [INTERVIEW_ROOM_API.md](./INTERVIEW_ROOM_API.md) - Interview Room API specification
- [USER_AUTH_API.md](./USER_AUTH_API.md) - User authentication system
- [CLAUDE.md](./CLAUDE.md) - Project architecture overview
