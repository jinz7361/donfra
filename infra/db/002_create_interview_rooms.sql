-- Migration: Create interview_rooms table
-- This table stores interview room information with user-based ownership

CREATE TABLE IF NOT EXISTS interview_rooms (
    id SERIAL PRIMARY KEY,
    room_id VARCHAR(255) UNIQUE NOT NULL,
    owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    headcount INTEGER DEFAULT 0,
    code_snapshot TEXT DEFAULT '',
    invite_link VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);

-- Index for faster lookups
CREATE INDEX idx_interview_rooms_room_id ON interview_rooms(room_id);
CREATE INDEX idx_interview_rooms_owner_id ON interview_rooms(owner_id);
CREATE INDEX idx_interview_rooms_deleted_at ON interview_rooms(deleted_at);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_interview_rooms_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_interview_rooms_updated_at
    BEFORE UPDATE ON interview_rooms
    FOR EACH ROW
    EXECUTE FUNCTION update_interview_rooms_updated_at();
