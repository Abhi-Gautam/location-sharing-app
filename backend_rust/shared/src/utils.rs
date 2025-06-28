use chrono::{DateTime, Utc, Duration};
use uuid::Uuid;
use rand::Rng;
use crate::types::Constants;

/// Utility functions for common operations

/// Generate a random avatar color from predefined set
pub fn generate_avatar_color() -> String {
    let mut rng = rand::thread_rng();
    let colors = Constants::DEFAULT_AVATAR_COLORS;
    let index = rng.gen_range(0..colors.len());
    colors[index].to_string()
}

/// Calculate session expiration time based on duration in minutes
pub fn calculate_expiration_time(duration_minutes: i64) -> DateTime<Utc> {
    Utc::now() + Duration::minutes(duration_minutes)
}

/// Check if a session has expired
pub fn is_session_expired(expires_at: DateTime<Utc>) -> bool {
    Utc::now() > expires_at
}

/// Check if a session should auto-expire due to inactivity
pub fn should_auto_expire(last_activity: DateTime<Utc>) -> bool {
    let inactivity_threshold = Utc::now() - Duration::minutes(Constants::SESSION_AUTO_EXPIRE_MINUTES);
    last_activity < inactivity_threshold
}

/// Generate a join link for a session
pub fn generate_join_link(session_id: Uuid, base_url: &str) -> String {
    format!("{}/join/{}", base_url, session_id)
}

/// Generate a WebSocket URL for connection
pub fn generate_websocket_url(base_ws_url: &str) -> String {
    format!("{}/ws", base_ws_url)
}

/// Validate hex color format
pub fn is_valid_hex_color(color: &str) -> bool {
    if !color.starts_with('#') || color.len() != 7 {
        return false;
    }
    
    color.chars().skip(1).all(|c| c.is_ascii_hexdigit())
}

/// Sanitize display name by trimming whitespace and limiting length
pub fn sanitize_display_name(name: &str) -> String {
    name.trim().chars().take(100).collect()
}

/// Sanitize session name by trimming whitespace and limiting length
pub fn sanitize_session_name(name: &str) -> String {
    name.trim().chars().take(255).collect()
}

/// Generate a unique user ID for anonymous participants
pub fn generate_user_id() -> String {
    Uuid::new_v4().to_string()
}

/// Calculate distance between two coordinates using Haversine formula
pub fn calculate_distance(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    const R: f64 = 6371000.0; // Earth's radius in meters
    
    let lat1_rad = lat1.to_radians();
    let lat2_rad = lat2.to_radians();
    let delta_lat = (lat2 - lat1).to_radians();
    let delta_lng = (lng2 - lng1).to_radians();
    
    let a = (delta_lat / 2.0).sin().powi(2) + 
            lat1_rad.cos() * lat2_rad.cos() * (delta_lng / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());
    
    R * c
}

/// Format duration in a human-readable way
pub fn format_duration(duration: Duration) -> String {
    let total_seconds = duration.num_seconds();
    let hours = total_seconds / 3600;
    let minutes = (total_seconds % 3600) / 60;
    let seconds = total_seconds % 60;
    
    if hours > 0 {
        format!("{}h {}m {}s", hours, minutes, seconds)
    } else if minutes > 0 {
        format!("{}m {}s", minutes, seconds)
    } else {
        format!("{}s", seconds)
    }
}

/// Generate a random session name if none provided
pub fn generate_session_name() -> String {
    let adjectives = [
        "Amazing", "Brilliant", "Curious", "Dynamic", "Energetic",
        "Fantastic", "Glorious", "Happy", "Incredible", "Joyful",
        "Kinetic", "Luminous", "Magnificent", "Noble", "Outstanding",
        "Powerful", "Quick", "Radiant", "Spectacular", "Tremendous",
        "Unique", "Vibrant", "Wonderful", "Exciting", "Yearning", "Zealous"
    ];
    
    let nouns = [
        "Adventure", "Journey", "Quest", "Expedition", "Voyage",
        "Trip", "Excursion", "Tour", "Outing", "Exploration",
        "Discovery", "Mission", "Campaign", "Venture", "Safari",
        "Trek", "Hike", "Walk", "Ride", "Drive", "Flight", "Cruise",
        "Gathering", "Meetup", "Session", "Event"
    ];
    
    let mut rng = rand::thread_rng();
    let adjective = adjectives[rng.gen_range(0..adjectives.len())];
    let noun = nouns[rng.gen_range(0..nouns.len())];
    
    format!("{} {}", adjective, noun)
}

/// Check if a timestamp is within acceptable bounds for location updates
pub fn is_timestamp_valid(timestamp: DateTime<Utc>) -> bool {
    let now = Utc::now();
    let future_threshold = now + Duration::minutes(5);
    let past_threshold = now - Duration::hours(1);
    
    timestamp <= future_threshold && timestamp >= past_threshold
}

/// Truncate text to specified length with ellipsis
pub fn truncate_text(text: &str, max_length: usize) -> String {
    if text.len() <= max_length {
        text.to_string()
    } else {
        format!("{}...", &text[..max_length.saturating_sub(3)])
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    #[test]
    fn test_generate_avatar_color() {
        let color = generate_avatar_color();
        assert!(color.starts_with('#'));
        assert_eq!(color.len(), 7);
        assert!(Constants::DEFAULT_AVATAR_COLORS.contains(&color.as_str()));
    }

    #[test]
    fn test_is_valid_hex_color() {
        assert!(is_valid_hex_color("#FF5733"));
        assert!(is_valid_hex_color("#000000"));
        assert!(is_valid_hex_color("#FFFFFF"));
        assert!(!is_valid_hex_color("FF5733"));
        assert!(!is_valid_hex_color("#FF573"));
        assert!(!is_valid_hex_color("#GG5733"));
    }

    #[test]
    fn test_sanitize_display_name() {
        assert_eq!(sanitize_display_name("  John Doe  "), "John Doe");
        assert_eq!(sanitize_display_name(""), "");
        
        let long_name = "a".repeat(150);
        let sanitized = sanitize_display_name(&long_name);
        assert_eq!(sanitized.len(), 100);
    }

    #[test]
    fn test_calculate_distance() {
        // Distance between two points in San Francisco (approximately 1 km)
        let lat1 = 37.7749;
        let lng1 = -122.4194;
        let lat2 = 37.7849;
        let lng2 = -122.4094;
        
        let distance = calculate_distance(lat1, lng1, lat2, lng2);
        assert!(distance > 1000.0 && distance < 2000.0); // Roughly 1 km
    }

    #[test]
    fn test_is_session_expired() {
        let future_time = Utc::now() + Duration::hours(1);
        let past_time = Utc::now() - Duration::hours(1);
        
        assert!(!is_session_expired(future_time));
        assert!(is_session_expired(past_time));
    }

    #[test]
    fn test_should_auto_expire() {
        let recent_activity = Utc::now() - Duration::minutes(30);
        let old_activity = Utc::now() - Duration::hours(2);
        
        assert!(!should_auto_expire(recent_activity));
        assert!(should_auto_expire(old_activity));
    }

    #[test]
    fn test_is_timestamp_valid() {
        let now = Utc::now();
        let future = now + Duration::minutes(10); // Too far in future
        let past = now - Duration::hours(2); // Too far in past
        let valid = now - Duration::minutes(5); // Valid
        
        assert!(!is_timestamp_valid(future));
        assert!(!is_timestamp_valid(past));
        assert!(is_timestamp_valid(valid));
    }

    #[test]
    fn test_truncate_text() {
        assert_eq!(truncate_text("Hello", 10), "Hello");
        assert_eq!(truncate_text("Hello World", 5), "He...");
        assert_eq!(truncate_text("Hi", 5), "Hi");
    }
}