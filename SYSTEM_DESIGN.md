# System Design: Real-Time Location Sharing App

This document outlines the system architecture, features, and technical decisions for the real-time location sharing application.

---

## 1. Core Idea

A mobile application for Android and iOS that allows groups of users to share their real-time location within a private, temporary session. The primary goal is to provide a seamless, "at-a-glance" map view where all members of a group can see each other, designed for use cases like group travel, motorcycle convoys, and social meetups.

---

## 2. Features

### Phase 1: Minimum Viable Product (MVP)

- **Session Management:**
  - Ephemeral, one-tap session creation.
  - Unique, sharable session links.
  - Instant, no-signup-required session joining.
  - Manual "Leave Session" capability.
- **The Live Map:**
  - Real-time avatars for all participants on a single map.
  - **Dynamic Map View:** Automatic zoom and pan to keep all participants visible.
  - "Center on Me" button.
  - Basic user avatars with name/initials.

### Phase 2: High-Value Enhancements (Post-MVP)

- In-Session Chat
- Points of Interest (POIs)
- User Status Updates
- Persistent Sessions
- Notifications
- Location History

---

## 3. MVP Strategy: A Tale of Two Backends

For the MVP, we will pursue a dual-backend strategy to evaluate two distinct, powerful technology stacks. The goal is to build the same core functionality in both Rust and Elixir, serving a single Flutter client. This will allow for a practical evaluation of performance, developer experience, and overall robustness before committing to a single stack for Phase 2.

### 3.1. Shared Components

- **Client:** A single **Flutter** application will be built. It will be configured to point to either the Rust or Elixir backend for testing.
- **Databases:** Both backends will use the same **PostgreSQL** instance for user/session data and the same **Redis** instance for caching, geospatial queries, and Pub/Sub.

### 3.2. Route 1: The Rust Backend (Performance & Safety)

This route prioritizes raw performance and compile-time safety guarantees.

- **Architecture:** We will build two separate Rust microservices, likely sharing a common core library.
  - **API Server:** An HTTP server built with **Axum** on the **Tokio** runtime. It will handle user/session management and communicate with PostgreSQL.
  - **WebSocket Server:** A separate server, also using **Axum/Tokio**, to manage all persistent WebSocket connections. It will use the **`redis-rs`** library to interact with Redis for Pub/Sub and caching.
- **Diagram:**
  ```
  +--------------+     +----------------+     +--------------------+
  | Flutter App  |---->| Load Balancer  |---->| Rust API Server    |
  | (configurable)|     |                |---->| Rust WebSocket Srv |
  +--------------+     +----------------+     +--------------------+
  ```

### 3.3. Route 2: The Elixir Backend (Resilience & Concurrency)

This route prioritizes fault-tolerance and a design that is ideologically suited for real-time communication.

- **Architecture:** We will build a single, monolithic **Phoenix** application that handles both HTTP and WebSocket traffic, leveraging the underlying OTP framework.
  - **API & WebSockets:** Phoenix `Controllers` will handle standard HTTP requests, while **Phoenix Channels** will provide a rich, first-class abstraction for real-time communication.
  - **State Management:** We will leverage **GenServers** to create lightweight, supervised processes for each session, providing extreme fault-tolerance and clear state management.
- **Diagram:**
  ```
  +--------------+     +----------------+     +--------------------+
  | Flutter App  |---->| Load Balancer  |---->| Phoenix Application|
  | (configurable)|     |                |     | (Elixir/OTP)       |
  +--------------+     +----------------+     +--------------------+
  ```

### 3.4. Evaluation Criteria

Upon completion of the MVP, the two backends will be compared on:
1.  **Performance:** Latency, CPU/memory usage under load.
2.  **Developer Experience:** Ease of implementation, debugging, and iteration speed.
3.  **Robustness:** How well each system handles errors and recovers from failure.
4.  **Code Clarity:** How easy the code is to understand and maintain.
