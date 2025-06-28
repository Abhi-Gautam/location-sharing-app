# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a real-time location sharing application implementing a dual-backend strategy for MVP evaluation. The project consists of:

- **Rust Backend** (`backend_rust/`): High-performance microservices using Axum/Tokio
- **Elixir Backend** (`backend_elixir/`): Fault-tolerant Phoenix application with OTP
- **Flutter Mobile App** (`mobile_app/`): Cross-platform client configurable for either backend

## Architecture

### Dual Backend Strategy
Both backends implement identical functionality to allow performance and developer experience comparison:
- **Rust**: Two microservices (API server + WebSocket server) using Axum framework
- **Elixir**: Single Phoenix application with Controllers (HTTP) + Channels (WebSocket)

### Shared Infrastructure
- **Database**: PostgreSQL for user/session data (both backends)
- **Cache/PubSub**: Redis for geospatial queries and real-time communication (both backends)

## Development Setup

### Project Structure
- `backend_rust/` - Rust microservices (API + WebSocket servers)
- `backend_elixir/` - Phoenix application
- `mobile_app/` - Flutter cross-platform mobile app
- `SYSTEM_DESIGN.md` - Comprehensive architectural documentation

### Technology Stack
**Rust Backend:**
- Framework: Axum on Tokio runtime
- Database: PostgreSQL (via sqlx or diesel)
- Cache: Redis (via redis-rs)
- Architecture: Separate API and WebSocket microservices

**Elixir Backend:**
- Framework: Phoenix with LiveView
- WebSocket: Phoenix Channels
- State Management: GenServers for session management
- Supervision: OTP supervision trees for fault tolerance

**Flutter Mobile App:**
- Platform: Cross-platform (Android/iOS)
- Configuration: Environment-based backend selection
- Map Integration: Real-time location display
- Communication: HTTP API + WebSocket connections

## Core Features (MVP)
- Ephemeral session creation with shareable links
- Real-time location sharing via WebSocket
- Dynamic map view with all participants
- No-signup session joining
- Manual session departure

## Development Notes

### Session Management
Sessions are ephemeral and temporary by design. Both backends implement:
- Unique session ID generation
- Real-time participant tracking
- Automatic cleanup on session end

### WebSocket Architecture
**Rust**: Dedicated WebSocket server with Redis pub/sub
**Elixir**: Phoenix Channels with built-in PubSub

### Database Schema
PostgreSQL stores:
- Session metadata
- Participant information
- Temporary session state

Redis provides:
- Real-time location caching
- Geospatial queries
- Pub/Sub for live updates

## Backend Comparison Goals
The dual implementation allows evaluation of:
1. Performance (latency, resource usage)
2. Developer experience (ease of implementation)
3. Robustness (error handling, fault tolerance)
4. Code maintainability and clarity