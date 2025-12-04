-- Create lessons table if it doesn't exist (compatible with GORM defaults)
CREATE TABLE IF NOT EXISTS lessons (
    id SERIAL PRIMARY KEY,
    slug TEXT NOT NULL,
    title TEXT NOT NULL,
    markdown TEXT NOT NULL,
    excalidraw JSONB NOT NULL,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO lessons (slug, title, markdown, excalidraw, is_published)
VALUES
    ('intro-to-donfra', 'Intro to Donfra', '# Welcome\n\nThis is a sample lesson for testing.', '{"type":"excalidraw","elements":[]}', TRUE),
    ('advanced-collab', 'Advanced Collaboration', '## Collaboration\n\nTesting collaborative editing features.', '{"type":"excalidraw","elements":[{"id":"1","type":"rectangle"}]}', TRUE)
ON CONFLICT (slug) DO NOTHING;
