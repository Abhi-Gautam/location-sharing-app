/**
 * Visual Testing Dashboard Server
 * 
 * Features:
 * - Real-time test monitoring
 * - Live map visualization
 * - Performance metrics display
 * - Test control interface
 */

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
const chalk = require('chalk');
const axios = require('axios');

class DashboardServer {
  constructor(port = 3001) {
    this.port = port;
    this.app = express();
    this.server = http.createServer(this.app);
    this.io = socketIo(this.server, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"]
      }
    });
    
    this.activeSessions = new Map();
    this.activeUsers = new Map();
    this.metrics = {
      startTime: Date.now(),
      totalUsers: 0,
      totalSessions: 0,
      locationUpdates: 0,
      errors: [],
      performance: []
    };
    
    this.setupRoutes();
    this.setupSocketHandlers();
  }

  setupRoutes() {
    // Serve static files
    this.app.use(express.static(path.join(__dirname, 'public')));
    this.app.use(express.json());
    
    // Main dashboard
    this.app.get('/', (req, res) => {
      res.sendFile(path.join(__dirname, 'public', 'index.html'));
    });
    
    // Live map view
    this.app.get('/map', (req, res) => {
      res.sendFile(path.join(__dirname, 'public', 'live-map.html'));
    });
    
    // Metrics view
    this.app.get('/metrics', (req, res) => {
      res.sendFile(path.join(__dirname, 'public', 'metrics.html'));
    });
    
    // API endpoints
    this.app.get('/api/status', (req, res) => {
      res.json({
        uptime: Date.now() - this.metrics.startTime,
        activeSessions: this.activeSessions.size,
        activeUsers: this.activeUsers.size,
        totalUsers: this.metrics.totalUsers,
        totalSessions: this.metrics.totalSessions,
        locationUpdates: this.metrics.locationUpdates,
        errorCount: this.metrics.errors.length
      });
    });
    
    this.app.get('/api/sessions', (req, res) => {
      const sessions = Array.from(this.activeSessions.values());
      res.json(sessions);
    });
    
    this.app.get('/api/users', (req, res) => {
      const users = Array.from(this.activeUsers.values());
      res.json(users);
    });
    
    this.app.get('/api/metrics', (req, res) => {
      res.json({
        ...this.metrics,
        currentTime: Date.now()
      });
    });
    
    // Test control endpoints
    this.app.post('/api/test/start', async (req, res) => {
      try {
        const { users = 10, sessions = 1, duration = 300 } = req.body;
        console.log(chalk.blue(`🚀 Starting test: ${users} users, ${sessions} sessions, ${duration}s`));
        
        // Emit test start event to connected clients
        this.io.emit('test_started', { users, sessions, duration });
        
        res.json({ 
          success: true, 
          message: 'Test started successfully',
          config: { users, sessions, duration }
        });
      } catch (error) {
        console.error('Failed to start test:', error);
        res.status(500).json({ success: false, error: error.message });
      }
    });
    
    this.app.post('/api/test/stop', (req, res) => {
      console.log(chalk.yellow('⏹️  Stopping test'));
      this.io.emit('test_stopped');
      res.json({ success: true, message: 'Test stopped' });
    });
  }

  setupSocketHandlers() {
    this.io.on('connection', (socket) => {
      console.log(chalk.green(`📱 Dashboard client connected: ${socket.id}`));
      
      // Send current status to new client
      socket.emit('status_update', {
        activeSessions: Array.from(this.activeSessions.values()),
        activeUsers: Array.from(this.activeUsers.values()),
        metrics: this.metrics
      });
      
      // Handle session updates from test coordinator
      socket.on('session_created', (sessionData) => {
        this.activeSessions.set(sessionData.session_id, {
          ...sessionData,
          users: [],
          createdAt: Date.now()
        });
        this.metrics.totalSessions++;
        
        console.log(chalk.green(`📋 Session created: ${sessionData.name}`));
        this.broadcastUpdate();
      });
      
      socket.on('user_spawned', (userData) => {
        this.activeUsers.set(userData.id, {
          ...userData,
          joinedAt: Date.now(),
          locationUpdates: 0,
          lastLocation: null
        });
        
        // Add user to session
        if (this.activeSessions.has(userData.sessionId)) {
          const session = this.activeSessions.get(userData.sessionId);
          session.users.push(userData.id);
          this.activeSessions.set(userData.sessionId, session);
        }
        
        this.metrics.totalUsers++;
        console.log(chalk.blue(`👤 User spawned: ${userData.displayName}`));
        this.broadcastUpdate();
      });
      
      socket.on('location_update', (locationData) => {
        const { userId, location, timestamp } = locationData;
        
        if (this.activeUsers.has(userId)) {
          const user = this.activeUsers.get(userId);
          user.lastLocation = location;
          user.locationUpdates++;
          user.lastUpdate = timestamp;
          this.activeUsers.set(userId, user);
        }
        
        this.metrics.locationUpdates++;
        
        // Broadcast location update to map viewers
        this.io.emit('location_update', locationData);
      });
      
      socket.on('test_error', (errorData) => {
        this.metrics.errors.push({
          ...errorData,
          timestamp: Date.now()
        });
        
        console.error(chalk.red(`❌ Test error: ${errorData.message}`));
        this.io.emit('error_occurred', errorData);
      });
      
      socket.on('performance_metric', (metricData) => {
        this.metrics.performance.push({
          ...metricData,
          timestamp: Date.now()
        });
        
        // Emit to metrics dashboard
        this.io.emit('performance_update', metricData);
      });
      
      socket.on('disconnect', () => {
        console.log(chalk.gray(`📱 Dashboard client disconnected: ${socket.id}`));
      });
    });
  }

  broadcastUpdate() {
    const update = {
      activeSessions: Array.from(this.activeSessions.values()),
      activeUsers: Array.from(this.activeUsers.values()),
      metrics: {
        ...this.metrics,
        currentTime: Date.now()
      }
    };
    
    this.io.emit('status_update', update);
  }

  // Periodic status broadcast
  startStatusBroadcast() {
    setInterval(() => {
      this.broadcastUpdate();
    }, 5000); // Every 5 seconds
  }

  // Health check for backend services
  async checkBackendHealth() {
    try {
      const response = await axios.get('http://localhost:4000/health', { timeout: 5000 });
      return { backend: response.status === 200 };
    } catch (error) {
      return { backend: false, error: error.message };
    }
  }

  async checkFrontendHealth() {
    try {
      const response = await axios.get('http://localhost:52778', { timeout: 5000 });
      return { frontend: response.status === 200 };
    } catch (error) {
      return { frontend: false, error: error.message };
    }
  }

  // Start monitoring service health
  startHealthMonitoring() {
    setInterval(async () => {
      const backendHealth = await this.checkBackendHealth();
      const frontendHealth = await this.checkFrontendHealth();
      
      const healthStatus = {
        ...backendHealth,
        ...frontendHealth,
        timestamp: Date.now()
      };
      
      this.io.emit('health_update', healthStatus);
      
      if (!healthStatus.backend || !healthStatus.frontend) {
        console.warn(chalk.yellow('⚠️  Service health issue detected'));
      }
    }, 10000); // Every 10 seconds
  }

  start() {
    this.server.listen(this.port, () => {
      console.log(chalk.green(`🎛️  Visual Testing Dashboard running on http://localhost:${this.port}`));
      console.log(chalk.blue(`📊 Live Map: http://localhost:${this.port}/map`));
      console.log(chalk.blue(`📈 Metrics: http://localhost:${this.port}/metrics`));
    });
    
    this.startStatusBroadcast();
    this.startHealthMonitoring();
  }

  stop() {
    this.server.close(() => {
      console.log(chalk.gray('🎛️  Dashboard server stopped'));
    });
  }
}

// CLI execution
if (require.main === module) {
  const port = process.env.PORT || 3001;
  const dashboard = new DashboardServer(port);
  dashboard.start();
  
  // Graceful shutdown
  process.on('SIGINT', () => {
    console.log(chalk.yellow('\n🛑 Shutting down dashboard server...'));
    dashboard.stop();
    process.exit(0);
  });
}

module.exports = DashboardServer;