-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Sessions table
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    creator_id UUID NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Participants table
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    avatar_color VARCHAR(7) DEFAULT '#FF5733',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(session_id, user_id)
);

-- Indexes for better query performance
CREATE INDEX idx_sessions_active ON sessions(is_active, expires_at);
CREATE INDEX idx_sessions_activity ON sessions(last_activity);
CREATE INDEX idx_sessions_creator ON sessions(creator_id);
CREATE INDEX idx_participants_session ON participants(session_id, is_active);
CREATE INDEX idx_participants_user ON participants(user_id);
CREATE INDEX idx_participants_last_seen ON participants(last_seen);

-- Add check constraints for data validation
ALTER TABLE sessions ADD CONSTRAINT chk_sessions_expires_after_created 
    CHECK (expires_at > created_at);

ALTER TABLE participants ADD CONSTRAINT chk_participants_avatar_color_format 
    CHECK (avatar_color ~ '^#[0-9A-Fa-f]{6}$');

ALTER TABLE participants ADD CONSTRAINT chk_participants_display_name_not_empty 
    CHECK (LENGTH(TRIM(display_name)) > 0);

-- Function to automatically update last_activity when participants are updated
CREATE OR REPLACE FUNCTION update_session_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE sessions 
    SET last_activity = NOW() 
    WHERE id = NEW.session_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update session activity when participants join/leave/update
CREATE TRIGGER trigger_update_session_activity
    AFTER INSERT OR UPDATE ON participants
    FOR EACH ROW
    EXECUTE FUNCTION update_session_activity();

-- Function to clean up expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS BIGINT AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    -- Mark expired sessions as inactive
    WITH expired_sessions AS (
        UPDATE sessions 
        SET is_active = false 
        WHERE is_active = true 
        AND expires_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*) INTO expired_count FROM expired_sessions;
    
    -- Mark participants in expired sessions as inactive
    UPDATE participants 
    SET is_active = false 
    WHERE session_id IN (
        SELECT id FROM sessions 
        WHERE is_active = false 
        AND expires_at < NOW()
    );
    
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up inactive sessions (no active participants for > 1 hour)
CREATE OR REPLACE FUNCTION cleanup_inactive_sessions()
RETURNS BIGINT AS $$
DECLARE
    inactive_count INTEGER;
BEGIN
    -- Mark sessions with no recent activity as inactive
    WITH inactive_sessions AS (
        UPDATE sessions 
        SET is_active = false 
        WHERE is_active = true 
        AND last_activity < NOW() - INTERVAL '1 hour'
        AND NOT EXISTS (
            SELECT 1 FROM participants 
            WHERE participants.session_id = sessions.id 
            AND participants.is_active = true 
            AND participants.last_seen > NOW() - INTERVAL '1 hour'
        )
        RETURNING id
    )
    SELECT COUNT(*) INTO inactive_count FROM inactive_sessions;
    
    -- Mark participants in inactive sessions as inactive
    UPDATE participants 
    SET is_active = false 
    WHERE session_id IN (
        SELECT id FROM sessions 
        WHERE is_active = false 
        AND last_activity < NOW() - INTERVAL '1 hour'
    );
    
    RETURN inactive_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get active participant count for a session
CREATE OR REPLACE FUNCTION get_active_participant_count(session_uuid UUID)
RETURNS BIGINT AS $$
BEGIN
    RETURN (
        SELECT COUNT(*) 
        FROM participants 
        WHERE session_id = session_uuid 
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql;

-- Function to check if user is session creator
CREATE OR REPLACE FUNCTION is_session_creator(session_uuid UUID, creator_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM sessions 
        WHERE id = session_uuid 
        AND creator_id = creator_uuid 
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql;

-- Create a view for session statistics
CREATE VIEW session_stats AS
SELECT 
    s.id,
    s.name,
    s.created_at,
    s.expires_at,
    s.is_active,
    s.last_activity,
    COUNT(p.id) as total_participants,
    COUNT(p.id) FILTER (WHERE p.is_active = true) as active_participants,
    MAX(p.last_seen) as last_participant_activity
FROM sessions s
LEFT JOIN participants p ON s.id = p.session_id
GROUP BY s.id, s.name, s.created_at, s.expires_at, s.is_active, s.last_activity;

-- Create a view for participant details with session info
CREATE VIEW participant_details AS
SELECT 
    p.id as participant_id,
    p.session_id,
    p.user_id,
    p.display_name,
    p.avatar_color,
    p.joined_at,
    p.last_seen,
    p.is_active as participant_active,
    s.name as session_name,
    s.is_active as session_active,
    s.expires_at as session_expires_at
FROM participants p
JOIN sessions s ON p.session_id = s.id;