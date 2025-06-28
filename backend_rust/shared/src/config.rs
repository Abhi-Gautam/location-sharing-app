use config::{Config, ConfigError, Environment, File};
use serde::{Deserialize, Serialize};
use std::fmt;

/// Application configuration structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub database: DatabaseConfig,
    pub redis: RedisConfig,
    pub server: ServerConfig,
    pub jwt: JwtConfig,
    pub app: AppSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseConfig {
    pub url: String,
    pub max_connections: u32,
    pub min_connections: u32,
    pub connect_timeout: u64,
    pub idle_timeout: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RedisConfig {
    pub url: String,
    pub max_connections: u32,
    pub connection_timeout: u64,
    pub command_timeout: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub api_host: String,
    pub api_port: u16,
    pub ws_host: String,
    pub ws_port: u16,
    pub cors_allowed_origins: Vec<String>,
    pub request_timeout: u64,
    pub max_request_size: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JwtConfig {
    pub secret: String,
    pub expiration_hours: i64,
    pub algorithm: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub environment: String,
    pub log_level: String,
    pub base_url: String,
    pub base_ws_url: String,
    pub max_participants_per_session: usize,
    pub location_ttl_seconds: usize,
    pub session_cleanup_interval_minutes: u64,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            database: DatabaseConfig {
                url: "postgresql://dev:dev123@localhost:5432/location_sharing".to_string(),
                max_connections: 20,
                min_connections: 5,
                connect_timeout: 30,
                idle_timeout: 600,
            },
            redis: RedisConfig {
                url: "redis://localhost:6379".to_string(),
                max_connections: 20,
                connection_timeout: 5,
                command_timeout: 10,
            },
            server: ServerConfig {
                api_host: "0.0.0.0".to_string(),
                api_port: 8080,
                ws_host: "0.0.0.0".to_string(),
                ws_port: 8081,
                cors_allowed_origins: vec![
                    "http://localhost:3000".to_string(),
                    "http://localhost:8080".to_string(),
                ],
                request_timeout: 30,
                max_request_size: 1048576, // 1MB
            },
            jwt: JwtConfig {
                secret: "your-super-secret-jwt-key-change-in-production".to_string(),
                expiration_hours: 24,
                algorithm: "HS256".to_string(),
            },
            app: AppSettings {
                environment: "development".to_string(),
                log_level: "info".to_string(),
                base_url: "http://localhost:8080".to_string(),
                base_ws_url: "ws://localhost:8081".to_string(),
                max_participants_per_session: 50,
                location_ttl_seconds: 30,
                session_cleanup_interval_minutes: 5,
            },
        }
    }
}

impl AppConfig {
    /// Load configuration from environment variables and config files
    pub fn load() -> Result<Self, ConfigError> {
        let mut config = Config::builder()
            // Start with default values
            .add_source(Config::try_from(&AppConfig::default())?)
            // Add configuration file if it exists
            .add_source(File::with_name("config/default").required(false))
            .add_source(File::with_name("config/local").required(false))
            // Add environment-specific config
            .add_source(
                Environment::with_prefix("APP")
                    .prefix_separator("_")
                    .separator("__")
            );
        
        // Override specific values from direct environment variables
        if let Ok(database_url) = std::env::var("DATABASE_URL") {
            config = config.set_override("database.url", database_url)?;
        }
        
        if let Ok(redis_url) = std::env::var("REDIS_URL") {
            config = config.set_override("redis.url", redis_url)?;
        }
        
        if let Ok(jwt_secret) = std::env::var("JWT_SECRET") {
            config = config.set_override("jwt.secret", jwt_secret)?;
        }
        
        if let Ok(api_port) = std::env::var("RUST_API_PORT") {
            if let Ok(port) = api_port.parse::<u16>() {
                config = config.set_override("server.api_port", port)?;
            }
        }
        
        if let Ok(ws_port) = std::env::var("RUST_WS_PORT") {
            if let Ok(port) = ws_port.parse::<u16>() {
                config = config.set_override("server.ws_port", port)?;
            }
        }
        
        config.build()?.try_deserialize()
    }
    
    /// Validate configuration values
    pub fn validate(&self) -> Result<(), String> {
        // Validate database URL
        if self.database.url.is_empty() {
            return Err("Database URL cannot be empty".to_string());
        }
        
        // Validate Redis URL
        if self.redis.url.is_empty() {
            return Err("Redis URL cannot be empty".to_string());
        }
        
        // Validate JWT secret
        if self.jwt.secret.is_empty() {
            return Err("JWT secret cannot be empty".to_string());
        }
        
        if self.jwt.secret.len() < 32 {
            return Err("JWT secret should be at least 32 characters long".to_string());
        }
        
        // Validate ports
        if self.server.api_port == 0 {
            return Err("API port must be specified".to_string());
        }
        
        if self.server.ws_port == 0 {
            return Err("WebSocket port must be specified".to_string());
        }
        
        if self.server.api_port == self.server.ws_port {
            return Err("API and WebSocket ports must be different".to_string());
        }
        
        // Validate connection limits
        if self.database.max_connections == 0 {
            return Err("Database max connections must be greater than 0".to_string());
        }
        
        if self.database.min_connections > self.database.max_connections {
            return Err("Database min connections cannot exceed max connections".to_string());
        }
        
        if self.redis.max_connections == 0 {
            return Err("Redis max connections must be greater than 0".to_string());
        }
        
        // Validate app settings
        if self.app.max_participants_per_session == 0 {
            return Err("Max participants per session must be greater than 0".to_string());
        }
        
        if self.app.location_ttl_seconds == 0 {
            return Err("Location TTL must be greater than 0".to_string());
        }
        
        Ok(())
    }
    
    /// Get database connection options
    pub fn database_options(&self) -> sqlx::postgres::PgConnectOptions {
        use sqlx::postgres::PgConnectOptions;
        use std::str::FromStr;
        
        PgConnectOptions::from_str(&self.database.url)
            .unwrap_or_else(|_| {
                // Fallback to default if URL parsing fails
                PgConnectOptions::new()
                    .host("localhost")
                    .port(5432)
                    .username("dev")
                    .password("dev123")
                    .database("location_sharing")
            })
    }
    
    /// Get database pool options
    pub fn database_pool_options(&self) -> sqlx::postgres::PgPoolOptions {
        sqlx::postgres::PgPoolOptions::new()
            .max_connections(self.database.max_connections)
            .min_connections(self.database.min_connections)
            .acquire_timeout(std::time::Duration::from_secs(self.database.connect_timeout))
            .idle_timeout(std::time::Duration::from_secs(self.database.idle_timeout))
    }
    
    /// Check if running in production environment
    pub fn is_production(&self) -> bool {
        self.app.environment.to_lowercase() == "production"
    }
    
    /// Check if running in development environment
    pub fn is_development(&self) -> bool {
        self.app.environment.to_lowercase() == "development"
    }
    
    /// Get API server address
    pub fn api_address(&self) -> String {
        format!("{}:{}", self.server.api_host, self.server.api_port)
    }
    
    /// Get WebSocket server address
    pub fn ws_address(&self) -> String {
        format!("{}:{}", self.server.ws_host, self.server.ws_port)
    }
}

// Custom Display implementation to hide sensitive information
impl fmt::Display for AppConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "AppConfig {{ ")?;
        write!(f, "environment: {}, ", self.app.environment)?;
        write!(f, "api_port: {}, ", self.server.api_port)?;
        write!(f, "ws_port: {}, ", self.server.ws_port)?;
        write!(f, "log_level: {}, ", self.app.log_level)?;
        write!(f, "max_participants: {} ", self.app.max_participants_per_session)?;
        write!(f, "}}")
    }
}