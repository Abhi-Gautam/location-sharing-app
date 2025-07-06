# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a real-time location sharing application built with **Elixir Phoenix backend** and **Flutter mobile app**. After comprehensive stress testing and complexity analysis, we selected a single-backend architecture for optimal simplicity and performance.

- **Elixir Backend** (`backend_elixir/`): Unified Phoenix application with REST API and WebSocket Channels
- **Flutter Mobile App** (`mobile_app/`): Cross-platform client for real-time location sharing

## Architecture

### Elixir-Only Architecture
Single Phoenix application providing all backend services:
- **REST API**: Session management, participant handling, authentication
- **WebSocket Channels**: Real-time location updates and broadcasting
- **BEAM Processes**: Session coordination and state management without external dependencies

### Infrastructure
- **Database**: PostgreSQL for session and participant data
- **State Management**: Pure BEAM processes (no Redis dependency)
- **Fault Tolerance**: OTP supervision trees for automatic recovery

## Development Setup

### Project Structure
- `backend_elixir/` - Phoenix application (REST API + WebSocket Channels)
- `mobile_app/` - Flutter cross-platform mobile app  
- `PRD.md` - Complete product requirements and architectural decisions

### Technology Stack
**Elixir Backend:**
- Framework: Phoenix 1.7+ with OTP supervision
- Database: Ecto 3.10+ with PostgreSQL
- WebSocket: Phoenix Channels
- State Management: GenServer processes + ETS tables
- Real-time: Phoenix PubSub (built on BEAM processes)
- Authentication: Guardian for JWT
- Monitoring: PromEx for metrics collection

**Flutter Mobile App:**
- Platform: Cross-platform (Android/iOS)
- State Management: Riverpod
- Map Integration: Google Maps with real-time participant tracking
- Communication: HTTP API + Phoenix Channels WebSocket

## Core Features (MVP)
- Ephemeral session creation with shareable links
- Real-time location sharing via WebSocket
- Dynamic map view with all participants
- No-signup session joining
- Manual session departure

## Development Notes

### Session Management
Sessions are ephemeral and temporary by design:
- Unique session ID generation  
- Real-time participant tracking via GenServer processes
- Automatic cleanup on session end via OTP supervision

### WebSocket Architecture
Phoenix Channels with built-in PubSub for real-time communication:
- Location updates broadcast to session participants
- Join/leave notifications
- Connection health monitoring

### Database Schema
PostgreSQL stores:
- Session metadata (name, expiration, creator)
- Participant information (display name, avatar, activity)
- Persistent data for session validation

### State Management
BEAM processes provide in-memory coordination:
- Per-session GenServer for participant state
- ETS tables for fast participant lookups
- Phoenix PubSub for message broadcasting
- OTP supervision for fault tolerance

## Architecture Decision
After comprehensive stress testing (10K+ concurrent users) and complexity analysis:
- **Performance**: 24ms WebSocket connections, 150ms API responses - excellent for location sharing
- **Simplicity**: Single service deployment vs distributed system complexity
- **Reliability**: Built-in OTP fault tolerance vs manual error handling
- **Development**: Unified codebase vs service boundaries and contracts