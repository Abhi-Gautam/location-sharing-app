use axum::{
    body::Body,
    http::{Method, Request, StatusCode},
    Router,
};
use serde_json::json;
use shared::{AppConfig, CreateSessionRequest, JoinSessionRequest};
use sqlx::PgPool;
use std::sync::Arc;
use tower::ServiceExt;

// Helper function to create a test app
async fn create_test_app() -> Router {
    let config = Arc::new(AppConfig::default());
    
    // For testing, you might want to use an in-memory database or test database
    // This is a simplified example
    let database_url = std::env::var("TEST_DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://test:test@localhost:5432/location_sharing_test".to_string());
    
    let db = PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to test database");
    
    let state = api_server::AppState {
        db,
        config,
    };
    
    api_server::create_router(state).await.unwrap()
}

#[tokio::test]
async fn test_health_check() {
    let app = create_test_app().await;
    
    let request = Request::builder()
        .method(Method::GET)
        .uri("/health")
        .body(Body::empty())
        .unwrap();
    
    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::OK);
}

#[tokio::test]
async fn test_create_session() {
    let app = create_test_app().await;
    
    let create_request = CreateSessionRequest {
        name: Some("Test Session".to_string()),
        expires_in_minutes: 60,
    };
    
    let request = Request::builder()
        .method(Method::POST)
        .uri("/api/sessions")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_string(&create_request).unwrap()))
        .unwrap();
    
    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::CREATED);
}

#[tokio::test]
async fn test_join_session_invalid_session_id() {
    let app = create_test_app().await;
    
    let join_request = JoinSessionRequest {
        display_name: "Test User".to_string(),
        avatar_color: Some("#FF5733".to_string()),
    };
    
    let session_id = uuid::Uuid::new_v4();
    
    let request = Request::builder()
        .method(Method::POST)
        .uri(&format!("/api/sessions/{}/join", session_id))
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_string(&join_request).unwrap()))
        .unwrap();
    
    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn test_validation_errors() {
    let app = create_test_app().await;
    
    // Test empty display name
    let invalid_request = JoinSessionRequest {
        display_name: "".to_string(),
        avatar_color: None,
    };
    
    let session_id = uuid::Uuid::new_v4();
    
    let request = Request::builder()
        .method(Method::POST)
        .uri(&format!("/api/sessions/{}/join", session_id))
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_string(&invalid_request).unwrap()))
        .unwrap();
    
    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
}

// Add this to the API server's Cargo.toml under [dev-dependencies]
// tokio-test = "0.4"
// tower = { version = "0.4", features = ["util"] }