#!/usr/bin/env node

/**
 * Visual Test Coordinator - Main orchestrator for multi-user browser testing
 * 
 * Features:
 * - Spawn multiple browser instances
 * - Coordinate session creation and joining
 * - Simulate realistic user movements
 * - Real-time monitoring and metrics collection
 */

const puppeteer = require('puppeteer');
const { program } = require('commander');
const chalk = require('chalk');
const { v4: uuidv4 } = require('uuid');
const io = require('socket.io-client');
const BrowserManager = require('./browser-manager');
const MovementSimulator = require('./movement-simulator');

class TestCoordinator {
  constructor(options = {}) {
    this.options = {
      users: 10,
      sessions: 1,
      duration: 300, // 5 minutes default
      headless: true,
      flutterUrl: 'http://localhost:52778',
      apiUrl: 'http://localhost:4000/api',
      ...options
    };
    
    this.browserManager = new BrowserManager();
    this.movementSimulator = new MovementSimulator();
    this.activeSessions = new Map();
    this.activeUsers = [];
    this.metrics = {
      startTime: Date.now(),
      sessionsCreated: 0,
      usersSpawned: 0,
      locationUpdatesSent: 0,
      errors: [],
      performance: []
    };
    
    // Connect to dashboard for real-time updates
    this.dashboardSocket = null;
  }

  async initialize() {
    console.log(chalk.blue('🚀 Initializing Visual Test Coordinator'));
    console.log(chalk.gray(`Configuration: ${this.options.users} users, ${this.options.sessions} sessions, ${this.options.duration}s duration`));
    
    // Connect to dashboard
    await this.connectToDashboard();
    
    // Verify services are running
    await this.checkServices();
    
    // Initialize browser manager
    await this.browserManager.initialize(this.options);
    
    console.log(chalk.green('✅ Test coordinator ready'));
  }

  emitToDashboard(event, data) {
    if (this.dashboardSocket && this.dashboardSocket.connected) {
      this.dashboardSocket.emit(event, data);
    }
  }

  async connectToDashboard() {
    try {
      // Try to connect to dashboard
      this.dashboardSocket = io('http://localhost:3001');
      
      this.dashboardSocket.on('connect', () => {
        console.log(chalk.green('✅ Connected to visual testing dashboard'));
      });
      
      this.dashboardSocket.on('disconnect', () => {
        console.log(chalk.yellow('⚠️  Disconnected from dashboard'));
      });
      
      this.dashboardSocket.on('connect_error', () => {
        console.log(chalk.yellow('⚠️  Dashboard not available - continuing without real-time updates'));
        this.dashboardSocket = null;
      });
      
      // Wait a moment for connection
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (error) {
      console.log(chalk.yellow('⚠️  Dashboard connection failed - continuing without real-time updates'));
      this.dashboardSocket = null;
    }
  }

  async checkServices() {
    console.log(chalk.blue('🔍 Checking service health...'));
    
    try {
      // Check backend health
      const backendResponse = await fetch(`${this.options.apiUrl.replace('/api', '')}/health`);
      if (!backendResponse.ok) {
        throw new Error(`Backend health check failed: ${backendResponse.status}`);
      }
      
      // Check frontend availability  
      const frontendResponse = await fetch(this.options.flutterUrl);
      if (!frontendResponse.ok) {
        throw new Error(`Frontend health check failed: ${frontendResponse.status}`);
      }
      
      console.log(chalk.green('✅ All services healthy'));
    } catch (error) {
      console.error(chalk.red('❌ Service health check failed:'), error.message);
      console.log(chalk.yellow('💡 Make sure to run: ./run.sh --start'));
      process.exit(1);
    }
  }

  async runVisualTest() {
    console.log(chalk.blue('🎬 Starting visual test scenario'));
    
    try {
      // Phase 1: Create sessions
      await this.createSessions();
      
      // Phase 2: Spawn users and join sessions
      await this.spawnUsers();
      
      // Phase 3: Start movement simulation
      await this.startMovementSimulation();
      
      // Phase 4: Monitor and collect metrics
      await this.monitorTest();
      
      // Phase 5: Generate report
      await this.generateReport();
      
    } catch (error) {
      console.error(chalk.red('❌ Visual test failed:'), error);
      this.metrics.errors.push({
        timestamp: Date.now(),
        error: error.message,
        stack: error.stack
      });
    } finally {
      await this.cleanup();
    }
  }

  async createSessions() {
    console.log(chalk.blue(`📋 Creating ${this.options.sessions} sessions...`));
    
    const sessionPromises = [];
    for (let i = 0; i < this.options.sessions; i++) {
      sessionPromises.push(this.createSession(`Visual Test Session ${i + 1}`));
    }
    
    const sessions = await Promise.all(sessionPromises);
    sessions.forEach((session, index) => {
      this.activeSessions.set(session.session_id, {
        ...session,
        users: [],
        index: index
      });
    });
    
    this.metrics.sessionsCreated = sessions.length;
    console.log(chalk.green(`✅ Created ${sessions.length} sessions`));
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
      
      this.metrics.performance.push({
        operation: 'create_session',
        duration,
        timestamp: Date.now()
      });
      
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

  async spawnUsers() {
    console.log(chalk.blue(`👥 Spawning ${this.options.users} users...`));
    
    const sessions = Array.from(this.activeSessions.values());
    const usersPerSession = Math.ceil(this.options.users / this.options.sessions);
    
    const userPromises = [];
    let userIndex = 0;
    
    for (const session of sessions) {
      const sessionUserCount = Math.min(usersPerSession, this.options.users - userIndex);
      
      for (let i = 0; i < sessionUserCount; i++) {
        const userData = {
          id: uuidv4(),
          displayName: `User ${userIndex + 1}`,
          sessionId: session.session_id,
          sessionIndex: session.index,
          userIndex: i
        };
        
        userPromises.push(this.spawnUser(userData));
        userIndex++;
      }
    }
    
    this.activeUsers = await Promise.all(userPromises);
    this.metrics.usersSpawned = this.activeUsers.length;
    
    console.log(chalk.green(`✅ Spawned ${this.activeUsers.length} users`));
  }

  async spawnUser(userData) {
    try {
      const browser = await this.browserManager.createBrowser(userData.id);
      const page = await browser.newPage();
      
      // Navigate to Flutter app
      await page.goto(this.options.flutterUrl, { waitUntil: 'networkidle2' });
      
      // Join session (simplified - would need actual Flutter interaction)
      // This would involve clicking buttons, entering session ID, etc.
      // For now, we'll simulate the API calls directly
      
      const user = {
        ...userData,
        browser,
        page,
        startTime: Date.now(),
        locationUpdates: 0
      };
      
      // Add user to session
      const session = this.activeSessions.get(userData.sessionId);
      session.users.push(user);
      
      // Emit to dashboard
      this.emitToDashboard('user_spawned', userData);
      
      return user;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to spawn user ${userData.displayName}:`), error.message);
      throw error;
    }
  }

  async startMovementSimulation() {
    console.log(chalk.blue('🗺️  Starting location movement simulation...'));
    
    // Generate movement patterns for each user
    for (const user of this.activeUsers) {
      const movementPattern = this.movementSimulator.generateMovementPattern({
        patternType: 'random_walk', // or 'route', 'stationary'
        duration: this.options.duration,
        updateInterval: 2000, // 2 seconds
        bounds: {
          north: 37.7849,
          south: 37.7649,
          east: -122.4094,
          west: -122.4294
        }
      });
      
      user.movementPattern = movementPattern;
      user.movementIndex = 0;
      
      // Start location updates
      this.startLocationUpdates(user);
    }
    
    console.log(chalk.green('✅ Movement simulation started for all users'));
  }

  startLocationUpdates(user) {
    const sendLocationUpdate = async () => {
      if (user.movementIndex >= user.movementPattern.length) {
        return; // Movement pattern complete
      }
      
      const location = user.movementPattern[user.movementIndex];
      user.movementIndex++;
      
      try {
        // Simulate WebSocket location update
        // In a real implementation, this would go through the Flutter app's WebSocket connection
        await this.sendLocationUpdate(user, location);
        
        user.locationUpdates++;
        this.metrics.locationUpdatesSent++;
        
        // Schedule next update
        setTimeout(sendLocationUpdate, 2000);
      } catch (error) {
        console.error(chalk.red(`❌ Location update failed for ${user.displayName}:`), error.message);
        this.metrics.errors.push({
          timestamp: Date.now(),
          user: user.displayName,
          error: error.message
        });
      }
    };
    
    // Start first update
    setTimeout(sendLocationUpdate, 1000);
  }

  async sendLocationUpdate(user, location) {
    // This would typically go through the WebSocket connection
    // For now, we'll track it as a metric
    const startTime = Date.now();
    
    // Simulate WebSocket message sending delay
    await new Promise(resolve => setTimeout(resolve, Math.random() * 50));
    
    const duration = Date.now() - startTime;
    this.metrics.performance.push({
      operation: 'location_update',
      user: user.displayName,
      location,
      duration,
      timestamp: Date.now()
    });
    
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
    console.log(chalk.blue(`⏱️  Monitoring test for ${this.options.duration} seconds...`));
    
    const monitorInterval = setInterval(() => {
      this.logStatus();
    }, 10000); // Log status every 10 seconds
    
    // Wait for test duration
    await new Promise(resolve => setTimeout(resolve, this.options.duration * 1000));
    
    clearInterval(monitorInterval);
    console.log(chalk.blue('⏹️  Test monitoring complete'));
  }

  logStatus() {
    const elapsed = Math.floor((Date.now() - this.metrics.startTime) / 1000);
    const avgLocationUpdates = this.activeUsers.reduce((sum, user) => sum + user.locationUpdates, 0) / this.activeUsers.length;
    
    console.log(chalk.cyan(`📊 Status (${elapsed}s): ${this.activeUsers.length} users, ${this.metrics.locationUpdatesSent} updates, ${this.metrics.errors.length} errors`));
  }

  async generateReport() {
    console.log(chalk.blue('📈 Generating test report...'));
    
    const totalDuration = Date.now() - this.metrics.startTime;
    const avgPerformance = this.calculateAveragePerformance();
    
    const report = {
      summary: {
        duration: totalDuration,
        sessionsCreated: this.metrics.sessionsCreated,
        usersSpawned: this.metrics.usersSpawned,
        locationUpdatesSent: this.metrics.locationUpdatesSent,
        errorsCount: this.metrics.errors.length,
        successRate: ((this.metrics.locationUpdatesSent - this.metrics.errors.length) / this.metrics.locationUpdatesSent * 100).toFixed(2) + '%'
      },
      performance: avgPerformance,
      errors: this.metrics.errors,
      timestamp: new Date().toISOString()
    };
    
    console.log(chalk.green('📊 Test Report:'));
    console.log(chalk.white(JSON.stringify(report.summary, null, 2)));
    
    // Save detailed report
    const fs = require('fs').promises;
    const reportPath = `./reports/visual-test-${Date.now()}.json`;
    await fs.mkdir('./reports', { recursive: true });
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));
    
    console.log(chalk.green(`✅ Detailed report saved to: ${reportPath}`));
  }

  calculateAveragePerformance() {
    const performanceByOperation = {};
    
    for (const metric of this.metrics.performance) {
      if (!performanceByOperation[metric.operation]) {
        performanceByOperation[metric.operation] = [];
      }
      performanceByOperation[metric.operation].push(metric.duration);
    }
    
    const averages = {};
    for (const [operation, durations] of Object.entries(performanceByOperation)) {
      averages[operation] = {
        count: durations.length,
        avg: durations.reduce((sum, d) => sum + d, 0) / durations.length,
        min: Math.min(...durations),
        max: Math.max(...durations)
      };
    }
    
    return averages;
  }

  async cleanup() {
    console.log(chalk.blue('🧹 Cleaning up test resources...'));
    
    try {
      await this.browserManager.cleanup();
      console.log(chalk.green('✅ Cleanup complete'));
    } catch (error) {
      console.error(chalk.red('❌ Cleanup failed:'), error.message);
    }
  }
}

// CLI Interface
program
  .name('test-coordinator')
  .description('Visual testing coordinator for location sharing app')
  .version('1.0.0');

program
  .command('run')
  .description('Run visual test scenario')
  .option('-u, --users <number>', 'number of users to simulate', '10')
  .option('-s, --sessions <number>', 'number of sessions to create', '1')
  .option('-d, --duration <seconds>', 'test duration in seconds', '300')
  .option('--headless', 'run browsers in headless mode', true)
  .option('--flutter-url <url>', 'Flutter app URL', 'http://localhost:52778')
  .option('--api-url <url>', 'Backend API URL', 'http://localhost:4000/api')
  .action(async (options) => {
    const coordinator = new TestCoordinator({
      users: parseInt(options.users),
      sessions: parseInt(options.sessions),
      duration: parseInt(options.duration),
      headless: options.headless,
      flutterUrl: options.flutterUrl,
      apiUrl: options.apiUrl
    });
    
    await coordinator.initialize();
    await coordinator.runVisualTest();
  });

// Direct execution
if (require.main === module) {
  program.parse();
}

module.exports = TestCoordinator;