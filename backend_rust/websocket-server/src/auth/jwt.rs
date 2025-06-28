use jsonwebtoken::{decode, DecodingKey, Validation, Algorithm};
use shared::{AppError, AppResult, JwtClaims};
use tracing::debug;

/// Verify JWT token and return claims
pub fn verify_jwt_token(token: &str, secret: &str) -> AppResult<JwtClaims> {
    debug!("Verifying JWT token");
    
    let validation = Validation::new(Algorithm::HS256);
    let token_data = decode::<JwtClaims>(
        token,
        &DecodingKey::from_secret(secret.as_ref()),
        &validation,
    )?;

    let claims = token_data.claims;
    
    // Check if token is expired
    let now = chrono::Utc::now().timestamp();
    if claims.exp < now {
        return Err(AppError::TokenExpired);
    }

    debug!("JWT token verified for user: {}", claims.sub);
    Ok(claims)
}

/// Extract token from WebSocket URL query parameters
pub fn extract_token_from_url(url: &str) -> Option<String> {
    url::Url::parse(url)
        .ok()?
        .query_pairs()
        .find(|(key, _)| key == "token")
        .map(|(_, value)| value.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, Utc};
    use jsonwebtoken::{encode, EncodingKey, Header};
    use uuid::Uuid;

    #[test]
    fn test_verify_valid_token() {
        let secret = "test-secret";
        let session_id = Uuid::new_v4();
        
        let claims = JwtClaims {
            sub: "test-user".to_string(),
            session_id,
            exp: (Utc::now() + Duration::hours(1)).timestamp(),
            iat: Utc::now().timestamp(),
        };

        let token = encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(secret.as_ref()),
        ).unwrap();

        let result = verify_jwt_token(&token, secret);
        assert!(result.is_ok());
        
        let verified_claims = result.unwrap();
        assert_eq!(verified_claims.sub, "test-user");
        assert_eq!(verified_claims.session_id, session_id);
    }

    #[test]
    fn test_verify_expired_token() {
        let secret = "test-secret";
        let session_id = Uuid::new_v4();
        
        let claims = JwtClaims {
            sub: "test-user".to_string(),
            session_id,
            exp: (Utc::now() - Duration::hours(1)).timestamp(), // Expired
            iat: Utc::now().timestamp(),
        };

        let token = encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(secret.as_ref()),
        ).unwrap();

        let result = verify_jwt_token(&token, secret);
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), AppError::TokenExpired));
    }

    #[test]
    fn test_verify_invalid_token() {
        let result = verify_jwt_token("invalid-token", "secret");
        assert!(result.is_err());
    }

    #[test]
    fn test_extract_token_from_url() {
        let url = "ws://localhost:8081/ws?token=abc123";
        let token = extract_token_from_url(url);
        assert_eq!(token, Some("abc123".to_string()));

        let url_no_token = "ws://localhost:8081/ws";
        let token = extract_token_from_url(url_no_token);
        assert_eq!(token, None);
    }
}