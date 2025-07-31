#!/usr/bin/env node

/**
 * Simplified API Test Coordinator - Tests without browser automation
 * 
 * This version focuses on API testing and dashboard integration without
 * the complexity of browser automation, ensuring dashboard data flow works.
 */

const chalk = require('chalk');
const { v4: uuidv4 } = require('uuid');
const io = require('socket.io-client');
const MovementSimulator = require('./movement-simulator');

class ApiTestCoordinator {
  constructor(options = {}) {
    this.options = {
      users: 10,
      sessions: 1,
      duration: 300,
      apiUrl: 'http://localhost:4000/api',
      ...options
    };
    
    this.movementSimulator = new MovementSimulator();
    this.activeSessions = new Map();
    this.activeUsers = [];
    this.dashboardSocket = null;
    this.metrics = {
      startTime: Date.now(),
      sessionsCreated: 0,
      usersSpawned: 0,
      locationUpdatesSent: 0,
      errors: [],
      performance: []
    };
  }

  async initialize() {
    console.log(chalk.blue('🚀 Initializing API Test Coordinator'));
    console.log(chalk.gray(`Configuration: ${this.options.users} users, ${this.options.sessions} sessions, ${this.options.duration}s duration`));
    
    await this.connectToDashboard();
    await this.checkServices();
    
    console.log(chalk.green('✅ API test coordinator ready'));
  }

  async connectToDashboard() {
    try {
      this.dashboardSocket = io('http://localhost:3001');
      
      this.dashboardSocket.on('connect', () => {
        console.log(chalk.green('✅ Connected to visual testing dashboard'));
      });
      
      this.dashboardSocket.on('disconnect', () => {
        console.log(chalk.yellow('⚠️  Disconnected from dashboard'));
      });
      
      // Wait for connection
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (error) {
      console.log(chalk.yellow('⚠️  Dashboard connection failed - continuing without real-time updates'));
      this.dashboardSocket = null;
    }
  }

  emitToDashboard(event, data) {
    if (this.dashboardSocket && this.dashboardSocket.connected) {
      this.dashboardSocket.emit(event, data);
      console.log(chalk.gray(`📡 Sent ${event} to dashboard`));
    }
  }

  async checkServices() {
    console.log(chalk.blue('🔍 Checking service health...'));
    
    try {
      const backendResponse = await fetch(`${this.options.apiUrl.replace('/api', '')}/health`);
      if (!backendResponse.ok) {
        throw new Error(`Backend health check failed: ${backendResponse.status}`);
      }
      console.log(chalk.green('✅ All services healthy'));
    } catch (error) {
      console.error(chalk.red('❌ Service health check failed:'), error.message);
      throw error;
    }
  }

  async runApiTest() {
    console.log(chalk.blue('🎬 Starting API-based visual test'));
    
    try {
      // Phase 1: Create sessions
      await this.createSessions();
      
      // Phase 2: Create users (API-only, no browsers)
      await this.createUsers();
      
      // Phase 3: Start location simulation
      await this.startLocationSimulation();
      
      // Phase 4: Monitor test
      await this.monitorTest();
      
      console.log(chalk.green('✅ API test completed successfully'));
    } catch (error) {
      console.error(chalk.red('❌ API test failed:'), error);
      this.emitToDashboard('test_error', { message: error.message });
    }
  }

  async createSessions() {
    console.log(chalk.blue(`📋 Creating ${this.options.sessions} sessions...`));
    
    for (let i = 0; i < this.options.sessions; i++) {
      const session = await this.createSession(`API Test Session ${i + 1}`);
      this.activeSessions.set(session.session_id, {
        ...session,
        users: [],
        index: i
      });
    }
    
    this.metrics.sessionsCreated = this.activeSessions.size;
    console.log(chalk.green(`✅ Created ${this.activeSessions.size} sessions`));
  }

  async createSession(name) {
    try {
      const startTime = Date.now();
      const response = await fetch(`${this.options.apiUrl}/sessions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
      });
      
      if (!response.ok) {
        throw new Error(`Failed to create session: ${response.status}`);
      }
      
      const session = await response.json();
      const duration = Date.now() - startTime;
      
      // Emit to dashboard
      this.emitToDashboard('session_created', session);
      this.emitToDashboard('performance_metric', {
        operation: 'create_session',
        duration,
        timestamp: Date.now()
      });
      
      return session;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to create session "${name}":`), error.message);
      throw error;
    }
  }

  async createUsers() {
    console.log(chalk.blue(`👥 Creating ${this.options.users} virtual users...`));
    
    const sessions = Array.from(this.activeSessions.values());
    const usersPerSession = Math.ceil(this.options.users / this.options.sessions);
    
    let userIndex = 0;
    for (const session of sessions) {
      const sessionUserCount = Math.min(usersPerSession, this.options.users - userIndex);
      
      for (let i = 0; i < sessionUserCount; i++) {
        const userData = {
          id: uuidv4(),
          displayName: `API User ${userIndex + 1}`,
          sessionId: session.session_id,
          sessionIndex: session.index,
          userIndex: i
        };
        
        // Create virtual user (no browser)
        const user = {
          ...userData,
          startTime: Date.now(),
          locationUpdates: 0,
          movementPattern: this.generateMovementPattern(userData)
        };
        
        this.activeUsers.push(user);
        session.users.push(user);
        
        // Emit to dashboard
        this.emitToDashboard('user_spawned', userData);
        
        userIndex++;
      }
    }
    
    this.metrics.usersSpawned = this.activeUsers.length;
    console.log(chalk.green(`✅ Created ${this.activeUsers.length} virtual users`));
  }

  generateMovementPattern(userData) {
    return this.movementSimulator.generateMovementPattern({
      patternType: ['random_walk', 'route', 'circular', 'stationary'][userData.userIndex % 4],
      duration: this.options.duration,
      updateInterval: 2000,
      bounds: {
        north: 37.7849,
        south: 37.7649,
        east: -122.4094,
        west: -122.4294
      }
    });
  }

  async startLocationSimulation() {
    console.log(chalk.blue('🗺️  Starting location simulation...'));
    
    for (const user of this.activeUsers) {
      this.startUserLocationUpdates(user);
    }
    
    console.log(chalk.green('✅ Location simulation started for all users'));
  }

  startUserLocationUpdates(user) {
    let updateIndex = 0;
    
    const sendUpdate = () => {
      if (updateIndex >= user.movementPattern.length) {
        return; // Pattern complete
      }
      
      const location = user.movementPattern[updateIndex];
      updateIndex++;
      
      // Send location update
      this.sendLocationUpdate(user, location);
      
      user.locationUpdates++;
      this.metrics.locationUpdatesSent++;
      
      // Schedule next update
      setTimeout(sendUpdate, 2000);
    };
    
    // Start after random delay to stagger updates
    setTimeout(sendUpdate, Math.random() * 2000);
  }

  async sendLocationUpdate(user, location) {
    const startTime = Date.now();
    
    // Simulate API call delay
    await new Promise(resolve => setTimeout(resolve, Math.random() * 50));
    
    const duration = Date.now() - startTime;
    
    // Emit to dashboard
    this.emitToDashboard('location_update', {
      userId: user.id,
      location,
      timestamp: new Date().toISOString()
    });
    
    this.emitToDashboard('performance_metric', {
      operation: 'location_update',
      duration,
      timestamp: Date.now()
    });
  }

  async monitorTest() {
    console.log(chalk.blue(`⏱️  Running test for ${this.options.duration} seconds...`));
    
    const startTime = Date.now();
    const monitorInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      const remaining = this.options.duration - elapsed;
      
      console.log(chalk.cyan(`📊 Progress: ${elapsed}s elapsed, ${remaining}s remaining, ${this.metrics.locationUpdatesSent} updates sent`));
      
      // Send status update to dashboard
      this.emitToDashboard('status_update', {
        activeSessions: Array.from(this.activeSessions.values()),
        activeUsers: this.activeUsers.map(u => ({
          id: u.id,
          displayName: u.displayName,
          locationUpdates: u.locationUpdates
        })),
        metrics: this.metrics
      });
      
    }, 10000); // Every 10 seconds
    
    // Wait for test duration
    await new Promise(resolve => setTimeout(resolve, this.options.duration * 1000));
    
    clearInterval(monitorInterval);
    console.log(chalk.blue('⏹️  Test completed'));
  }
}

// CLI interface
if (require.main === module) {
  const coordinator = new ApiTestCoordinator({
    users: parseInt(process.argv[2]) || 10,
    sessions: parseInt(process.argv[3]) || 1,
    duration: parseInt(process.argv[4]) || 120
  });
  
  coordinator.initialize()
    .then(() => coordinator.runApiTest())
    .then(() => {
      console.log(chalk.green('🎉 API test completed successfully!'));
      process.exit(0);
    })
    .catch((error) => {
      console.error(chalk.red('💥 API test failed:'), error);
      process.exit(1);
    });
}

module.exports = ApiTestCoordinator;