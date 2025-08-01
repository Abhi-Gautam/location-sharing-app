# Location Sharing App - Documentation

Welcome to the comprehensive documentation for the Location Sharing application - a real-time location sharing system built with Flutter (mobile) and Elixir Phoenix (backend).

## 📚 Documentation Structure

### 🚀 Quick Start
- [**Main README**](../README.md) - Get started quickly with the application
- [**Installation Guide**](deployment/installation.md) - Complete setup instructions
- [**API Reference**](backend/api-reference.md) - REST and WebSocket APIs

### 🏗️ Architecture
- [**System Architecture**](architecture.md) - High-level system design
- [**Backend Architecture**](backend/README.md) - Elixir Phoenix backend details
- [**Frontend Architecture**](frontend/README.md) - Flutter mobile app details

### 🧪 Testing
- [**Testing Guide**](testing/README.md) - Complete testing documentation

### 🚀 Deployment
- [**Deployment Guide**](deployment/README.md) - Production deployment

### 🔧 Troubleshooting
- [**Troubleshooting Guide**](troubleshooting.md) - Common issues and solutions

## 🎯 Getting Started

The fastest way to get started:

```bash
# 1. Clone the repository
git clone <repository-url>
cd location-sharing

# 2. Run complete setup
./run.sh --setup

# 3. Start all services
./run.sh --start

# 4. Run tests to verify everything works
./run.sh --test
```

## 🌟 Key Features

- **Real-time Location Sharing**: GPS tracking with 2-second updates
- **Cross-platform**: Flutter app for Android and iOS
- **Scalable Backend**: Elixir Phoenix with OTP supervision trees
- **Enterprise-ready**: Health checks, monitoring, comprehensive testing
- **Privacy-focused**: Ephemeral sessions, no permanent data storage

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │ Phoenix Backend │    │   PostgreSQL    │
│                 │◄──►│                 │◄──►│                 │
│ • Real-time UI  │    │ • REST API      │    │ • Session Data  │
│ • GPS Tracking  │    │ • WebSocket     │    │ • Participants  │
│ • Google Maps   │    │ • Broadcasting  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📱 Components

### Frontend (Flutter)
- **Mobile App**: Cross-platform Flutter application
- **Real-time Maps**: Google Maps with live participant tracking
- **State Management**: Riverpod for reactive state updates
- **WebSocket Client**: Real-time communication with backend

### Backend (Elixir Phoenix)
- **REST API**: Session and participant management
- **WebSocket Channels**: Real-time location broadcasting
- **Database**: PostgreSQL for persistent data
- **OTP Supervision**: Fault-tolerant process management

## 🔗 Quick Links

- [**Main Application README**](../README.md)
- [**Backend Documentation**](backend/README.md)
- [**Frontend Documentation**](frontend/README.md)
- [**Testing Documentation**](testing/README.md)
- [**CLAUDE.md**](../CLAUDE.md) - Developer guidance for AI assistants

## 💡 Use Cases

- **Group Travel**: Share locations during trips
- **Event Coordination**: Track participants at events
- **Outdoor Activities**: Safety for hiking, cycling groups
- **Team Coordination**: Real-time location sharing for teams

## 🛡️ Security & Privacy

- **Ephemeral Sessions**: 24-hour maximum duration
- **No Permanent Storage**: Location data is temporary
- **JWT Authentication**: Secure WebSocket connections
- **Input Validation**: Comprehensive parameter validation

## 📞 Support

For help and questions:
1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review relevant component documentation
3. Run health checks: `./run.sh --health`
4. Check service status: `./run.sh --status`

---

**Last Updated**: January 2025
**Version**: 1.0.0