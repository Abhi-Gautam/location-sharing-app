#!/usr/bin/env node

/**
 * Location Simulator
 * 
 * Simulates real-time location updates for API-created participants
 * by connecting to WebSocket channels and broadcasting location data.
 */

const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');

// Configuration
const WS_BASE_URL = 'ws://localhost:4000/socket/websocket';
const UPDATE_INTERVAL = 2000; // 2 seconds (matches Flutter app)
const CONFIG_FILE = 'api-test-config.json';

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',  
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

// Utility functions
function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function logInfo(message) {
  log(`ℹ️  ${message}`, colors.blue);
}

function logSuccess(message) {
  log(`✅ ${message}`, colors.green);
}

function logError(message) {
  log(`❌ ${message}`, colors.red);
}

function logWarning(message) {
  log(`⚠️  ${message}`, colors.yellow);
}

// Movement patterns
class MovementPattern {
  constructor(name, centerLat, centerLng, config = {}) {
    this.name = name;
    this.centerLat = centerLat;
    this.centerLng = centerLng;
    this.radius = config.radius || 0.01; // ~1km
    this.speed = config.speed || 1.4; // m/s (walking speed)
    this.currentLat = centerLat;
    this.currentLng = centerLng;
    this.direction = Math.random() * 2 * Math.PI; // Random initial direction
    this.lastUpdate = Date.now();
  }

  update() {
    const now = Date.now();
    const deltaTime = (now - this.lastUpdate) / 1000; // seconds
    this.lastUpdate = now;

    // Calculate distance to move (in degrees)
    const distanceKm = (this.speed * deltaTime) / 1000; // km
    const distanceDegrees = distanceKm / 111.32; // Rough conversion

    // Update position
    this.currentLat += Math.cos(this.direction) * distanceDegrees;
    this.currentLng += Math.sin(this.direction) * distanceDegrees;

    // Keep within radius of center
    const distance = this.getDistanceFromCenter();
    if (distance > this.radius) {
      // Turn back toward center
      this.direction = Math.atan2(
        this.centerLng - this.currentLng,
        this.centerLat - this.currentLat
      );
    } else {
      // Occasionally change direction
      if (Math.random() < 0.1) {
        this.direction += (Math.random() - 0.5) * Math.PI / 2;
      }
    }

    return {
      lat: this.currentLat,
      lng: this.currentLng,
      accuracy: 10 + Math.random() * 20 // 10-30m accuracy
    };
  }

  getDistanceFromCenter() {
    const latDiff = this.currentLat - this.centerLat;
    const lngDiff = this.currentLng - this.centerLng;
    return Math.sqrt(latDiff * latDiff + lngDiff * lngDiff);
  }
}

// Participant simulator
class ParticipantSimulator {
  constructor(sessionId, userId, displayName, websocketToken) {
    this.sessionId = sessionId;
    this.userId = userId;
    this.displayName = displayName;
    this.websocketToken = websocketToken;
    this.ws = null;
    this.isConnected = false;
    this.isJoined = false;
    this.movementPattern = null;
    this.updateInterval = null;
  }

  async connect() {
    return new Promise((resolve, reject) => {
      try {
        // Build WebSocket URL with authentication parameters (Phoenix format)
        const wsUrl = `${WS_BASE_URL}?token=${encodeURIComponent(this.websocketToken)}&session_id=${this.sessionId}&user_id=${this.userId}`;
        logInfo(`Connecting ${this.displayName} to WebSocket...`);
        
        this.ws = new WebSocket(wsUrl);

        this.ws.on('open', () => {
          logSuccess(`${this.displayName} connected to WebSocket`);
          this.isConnected = true;
          this.joinLocationChannel()
            .then(() => resolve())
            .catch(reject);
        });

        this.ws.on('message', (data) => {
          try {
            const message = JSON.parse(data.toString());
            this.handleMessage(message);
          } catch (error) {
            logError(`${this.displayName} - Error parsing message: ${error.message}`);
          }
        });

        this.ws.on('error', (error) => {
          logError(`${this.displayName} - WebSocket error: ${error.message}`);
          reject(error);
        });

        this.ws.on('close', (code, reason) => {
          logWarning(`${this.displayName} - WebSocket closed: ${code} ${reason}`);
          this.isConnected = false;
          this.isJoined = false;
          this.stopLocationUpdates();
        });

      } catch (error) {
        reject(error);
      }
    });
  }

  async joinLocationChannel() {
    return new Promise((resolve, reject) => {
      if (!this.isConnected) {
        reject(new Error('Not connected to WebSocket'));
        return;
      }

      const joinMessage = {
        topic: `location:${this.sessionId}`,
        event: 'phx_join',
        payload: {},
        ref: this.generateRef()
      };

      logInfo(`${this.displayName} joining location channel...`);
      this.ws.send(JSON.stringify(joinMessage));

      // Set timeout for join response
      const timeout = setTimeout(() => {
        reject(new Error('Join timeout'));
      }, 5000);

      // Store resolve/reject for handling in message handler
      this.joinResolve = () => {
        clearTimeout(timeout);
        resolve();
      };
      this.joinReject = (error) => {
        clearTimeout(timeout);
        reject(error);
      };
    });
  }

  handleMessage(message) {
    const { topic, event, payload, ref } = message;

    if (topic === `location:${this.sessionId}`) {
      switch (event) {
        case 'phx_reply':
          if (payload.status === 'ok') {
            logSuccess(`${this.displayName} joined location channel`);
            this.isJoined = true;
            this.startLocationUpdates();
            if (this.joinResolve) this.joinResolve();
          } else {
            logError(`${this.displayName} - Join failed: ${payload.response?.reason || 'unknown'}`);
            if (this.joinReject) this.joinReject(new Error(payload.response?.reason || 'join failed'));
          }
          break;

        case 'location_update':
          // Handle incoming location updates from other participants
          logInfo(`${this.displayName} received location update from ${payload.data?.user_id}`);
          break;

        case 'participant_joined':
          logInfo(`${this.displayName} - New participant joined: ${payload.data?.user_id}`);
          break;

        case 'participant_left':
          logInfo(`${this.displayName} - Participant left: ${payload.data?.user_id}`);
          break;

        default:
          logInfo(`${this.displayName} - Unhandled event: ${event}`);
      }
    }
  }

  startLocationUpdates() {
    if (!this.isJoined) return;

    // Create movement pattern with random center near San Francisco
    const baseLat = 37.7749 + (Math.random() - 0.5) * 0.1;
    const baseLng = -122.4194 + (Math.random() - 0.5) * 0.1;
    
    this.movementPattern = new MovementPattern(this.displayName, baseLat, baseLng, {
      radius: 0.02, // ~2km radius
      speed: 1.4 + Math.random() * 2.6 // 1.4-4.0 m/s (walking to driving)
    });

    logSuccess(`${this.displayName} starting location updates`);

    this.updateInterval = setInterval(() => {
      if (this.isJoined && this.ws && this.ws.readyState === WebSocket.OPEN) {
        const location = this.movementPattern.update();
        this.sendLocationUpdate(location);
      }
    }, UPDATE_INTERVAL);
  }

  sendLocationUpdate(location) {
    if (!this.isJoined || !this.ws || this.ws.readyState !== WebSocket.OPEN) return;

    const locationMessage = {
      topic: `location:${this.sessionId}`,
      event: 'location_update',
      payload: {
        lat: location.lat,
        lng: location.lng,
        accuracy: location.accuracy,
        timestamp: Date.now()
      },
      ref: this.generateRef()
    };

    this.ws.send(JSON.stringify(locationMessage));
    logInfo(`${this.displayName} sent location: ${location.lat.toFixed(6)}, ${location.lng.toFixed(6)}`);
  }

  stopLocationUpdates() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
      logInfo(`${this.displayName} stopped location updates`);
    }
  }

  disconnect() {
    this.stopLocationUpdates();
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.close();
    }
    logInfo(`${this.displayName} disconnected`);
  }

  generateRef() {
    return Math.random().toString(36).substr(2, 9);
  }
}

// Session simulator
class SessionSimulator {
  constructor() {
    this.participants = [];
    this.isRunning = false;
  }

  async loadSessionData(sessionResults) {
    logInfo('Loading session data for simulation...');
    
    for (const session of sessionResults.sessions) {
      logInfo(`Processing session: ${session.sessionName} (${session.sessionId})`);
      
      for (const participant of session.participants) {
        const simulator = new ParticipantSimulator(
          session.sessionId,
          participant.userId,
          participant.displayName,
          participant.websocketToken
        );
        
        this.participants.push(simulator);
      }
    }
  }

  async startSimulation() {
    if (this.isRunning) {
      logWarning('Simulation already running');
      return;
    }

    this.isRunning = true;
    logInfo(`Starting simulation for ${this.participants.length} participants...`);

    // Connect all participants
    const connectionPromises = this.participants.map(async (participant, index) => {
      // Stagger connections to avoid overwhelming the server
      await new Promise(resolve => setTimeout(resolve, index * 100));
      
      try {
        await participant.connect();
        logSuccess(`${participant.displayName} simulation started`);
      } catch (error) {
        logError(`Failed to start simulation for ${participant.displayName}: ${error.message}`);
      }
    });

    await Promise.allSettled(connectionPromises);
    
    const connectedCount = this.participants.filter(p => p.isJoined).length;
    logSuccess(`${connectedCount}/${this.participants.length} participants connected and simulating`);
  }

  stopSimulation() {
    if (!this.isRunning) return;

    logInfo('Stopping simulation...');
    this.isRunning = false;

    this.participants.forEach(participant => {
      participant.disconnect();
    });

    logSuccess('Simulation stopped');
  }

  getStatus() {
    const connected = this.participants.filter(p => p.isConnected).length;
    const joined = this.participants.filter(p => p.isJoined).length;
    
    return {
      total: this.participants.length,
      connected,
      joined,
      isRunning: this.isRunning
    };
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h')) {
    showUsage();
    return;
  }

  const sessionDataFile = args[0];
  if (!sessionDataFile) {
    logError('Please provide session data file');
    logInfo('Usage: node location-simulator.js <session-data.json>');
    process.exit(1);
  }

  try {
    // Load session data
    const sessionDataPath = path.resolve(sessionDataFile);
    if (!fs.existsSync(sessionDataPath)) {
      logError(`Session data file not found: ${sessionDataPath}`);
      process.exit(1);
    }

    const sessionData = JSON.parse(fs.readFileSync(sessionDataPath, 'utf8'));
    
    // Create and start simulator
    const simulator = new SessionSimulator();
    await simulator.loadSessionData(sessionData);
    
    // Handle graceful shutdown
    process.on('SIGINT', () => {
      log('\n🛑 Received SIGINT, stopping simulation...', colors.yellow);
      simulator.stopSimulation();
      process.exit(0);
    });

    process.on('SIGTERM', () => {
      log('\n🛑 Received SIGTERM, stopping simulation...', colors.yellow);
      simulator.stopSimulation();
      process.exit(0);
    });

    await simulator.startSimulation();

    // Keep running and show periodic status
    setInterval(() => {
      const status = simulator.getStatus();
      log(`📊 Status: ${status.joined}/${status.total} participants active`, colors.cyan);
    }, 10000); // Every 10 seconds

    // Keep the process alive
    log('🚀 Location simulation running. Press Ctrl+C to stop.', colors.green);
    await new Promise(() => {}); // Run forever

  } catch (error) {
    logError(`Failed to start location simulator: ${error.message}`);
    process.exit(1);
  }
}

function showUsage() {
  console.log(`
${colors.bright}Location Simulator${colors.reset}

Simulates real-time location updates for API-created participants.

${colors.cyan}USAGE:${colors.reset}
  node location-simulator.js <session-data.json>

${colors.cyan}DESCRIPTION:${colors.reset}
  - Connects to WebSocket channels for each API-created participant
  - Simulates realistic movement patterns around San Francisco
  - Sends location updates every 2 seconds
  - Handles multiple participants across multiple sessions

${colors.cyan}EXAMPLES:${colors.reset}
  # Run with session data from API creator
  node location-simulator.js session-results.json

${colors.cyan}REQUIREMENTS:${colors.reset}
  - Elixir backend running on localhost:4000
  - Session data JSON file with participant tokens
  - Node.js with WebSocket support

${colors.cyan}MOVEMENT PATTERNS:${colors.reset}
  - Each participant gets a random starting location near San Francisco
  - Participants move with realistic walking/driving speeds
  - Movement stays within a ~2km radius of starting point
  - Direction changes randomly to simulate realistic movement
`);
}

// Run if called directly
if (require.main === module) {
  main().catch(error => {
    logError(`Unhandled error: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { SessionSimulator, ParticipantSimulator, MovementPattern };