#!/usr/bin/env node

/**
 * API Session Creator
 * 
 * Creates multiple sessions with participants via the Elixir backend API
 * for manual testing with Flutter UI.
 */

const fs = require('fs');
const path = require('path');

// Configuration
const API_BASE_URL = 'http://localhost:4000/api';
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

// Load configuration
function loadConfig() {
  try {
    const configPath = path.join(__dirname, CONFIG_FILE);
    if (fs.existsSync(configPath)) {
      const configContent = fs.readFileSync(configPath, 'utf8');
      return JSON.parse(configContent);
    } else {
      logWarning(`Config file ${CONFIG_FILE} not found, using defaults`);
      return getDefaultConfig();
    }
  } catch (error) {
    logError(`Failed to load config: ${error.message}`);
    return getDefaultConfig();
  }
}

function getDefaultConfig() {
  return {
    scenarios: {
      basic: {
        sessions: 2,
        participantsPerSession: 3,
        sessionNames: ["Test Session 1", "Test Session 2"],
        participantNamePrefix: "Test User"
      },
      stress: {
        sessions: 5,
        participantsPerSession: 8,
        sessionNames: ["Stress Test 1", "Stress Test 2", "Stress Test 3", "Stress Test 4", "Stress Test 5"],
        participantNamePrefix: "Stress User"
      }
    }
  };
}

// API client functions
async function makeApiRequest(endpoint, method = 'GET', body = null) {
  const url = `${API_BASE_URL}${endpoint}`;
  
  const options = {
    method,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  try {
    const response = await fetch(url, options);
    const data = await response.json();

    if (!response.ok) {
      throw new Error(`API Error (${response.status}): ${data.error || 'Unknown error'}`);
    }

    return data;
  } catch (error) {
    if (error.code === 'ECONNREFUSED') {
      throw new Error('Cannot connect to backend. Make sure Elixir server is running on localhost:4000');
    }
    throw error;
  }
}

async function createSession(sessionName, expiresInMinutes = 1440) {
  logInfo(`Creating session: "${sessionName}"`);
  
  const sessionData = {
    name: sessionName,
    expires_in_minutes: expiresInMinutes
  };

  const result = await makeApiRequest('/sessions', 'POST', sessionData);
  logSuccess(`Session created: ${result.session_id}`);
  
  // Show join information immediately
  console.log('');
  console.log(`${colors.bright}${colors.yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
  console.log(`${colors.bright}${colors.green}🎯 JOIN THIS SESSION NOW!${colors.reset}`);
  console.log(`${colors.bright}${colors.yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
  console.log(`${colors.bright}📋 Session ID: ${colors.green}${result.session_id}${colors.reset}`);
  console.log(`${colors.bright}🔗 Quick Join: ${colors.blue}http://localhost:52778${colors.reset}`);
  console.log(`${colors.bright}   Then click "Join Session" and paste the Session ID${colors.reset}`);
  console.log(`${colors.bright}${colors.yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`);
  console.log('');
  
  return result;
}

async function addParticipant(sessionId, displayName, avatarColor = null) {
  logInfo(`Adding participant "${displayName}" to session ${sessionId}`);
  
  const participantData = {
    display_name: displayName,
    avatar_color: avatarColor || generateRandomColor()
  };

  const result = await makeApiRequest(`/sessions/${sessionId}/join`, 'POST', participantData);
  logSuccess(`Participant added: ${result.user_id}`);
  
  return result;
}

async function getSessionDetails(sessionId) {
  return await makeApiRequest(`/sessions/${sessionId}`);
}

async function getParticipants(sessionId) {
  return await makeApiRequest(`/sessions/${sessionId}/participants`);
}

// Helper functions
function generateRandomColor() {
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', 
    '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F',
    '#48C9B0', '#5DADE2', '#AF7AC5', '#F5B7B1'
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

function generateParticipantName(prefix, sessionIndex, participantIndex) {
  return `${prefix} ${sessionIndex}-${participantIndex}`;
}

// Main orchestration functions
async function createTestScenario(scenarioName, config) {
  log(`\n${colors.bright}=== Creating ${scenarioName.toUpperCase()} Scenario ===${colors.reset}`);
  
  const scenario = config.scenarios[scenarioName];
  if (!scenario) {
    throw new Error(`Scenario "${scenarioName}" not found in config`);
  }

  const results = {
    scenario: scenarioName,
    sessions: [],
    summary: {
      totalSessions: scenario.sessions,
      totalParticipants: scenario.sessions * scenario.participantsPerSession,
      createdSessions: 0,
      createdParticipants: 0
    }
  };

  // Create sessions
  for (let i = 0; i < scenario.sessions; i++) {
    try {
      const sessionName = scenario.sessionNames && scenario.sessionNames[i] 
        ? scenario.sessionNames[i] 
        : `${scenarioName} Session ${i + 1}`;

      const session = await createSession(sessionName);
      results.summary.createdSessions++;

      const sessionResult = {
        sessionId: session.session_id,
        sessionName: sessionName,
        joinLink: session.join_link,
        participants: []
      };

      // Add participants to this session
      for (let j = 0; j < scenario.participantsPerSession; j++) {
        try {
          const participantName = generateParticipantName(
            scenario.participantNamePrefix || 'Test User',
            i + 1,
            j + 1
          );

          const participant = await addParticipant(session.session_id, participantName);
          results.summary.createdParticipants++;

          sessionResult.participants.push({
            userId: participant.user_id,
            displayName: participantName,
            websocketToken: participant.websocket_token
          });

        } catch (error) {
          logError(`Failed to add participant ${j + 1} to session ${i + 1}: ${error.message}`);
        }
      }

      results.sessions.push(sessionResult);

    } catch (error) {
      logError(`Failed to create session ${i + 1}: ${error.message}`);
    }
  }

  return results;
}

function displayResults(results) {
  log(`\n${colors.bright}=== TEST SCENARIO RESULTS ===${colors.reset}`);
  log(`Scenario: ${colors.cyan}${results.scenario}${colors.reset}`);
  log(`Created Sessions: ${colors.green}${results.summary.createdSessions}/${results.summary.totalSessions}${colors.reset}`);
  log(`Created Participants: ${colors.green}${results.summary.createdParticipants}/${results.summary.totalParticipants}${colors.reset}`);

  if (results.sessions.length > 0) {
    // Save session data for location simulator
    saveSessionData(results);
    
    log(`\n${colors.bright}=== SESSIONS FOR MANUAL TESTING ===${colors.reset}`);
    
    results.sessions.forEach((session, index) => {
      log(`\n${colors.magenta}Session ${index + 1}: ${session.sessionName}${colors.reset}`);
      log(`  Session ID: ${colors.yellow}${session.sessionId}${colors.reset}`);
      log(`  Join Link: ${colors.blue}${session.joinLink}${colors.reset}`);
      log(`  Participants (${session.participants.length}):`);
      
      session.participants.forEach((participant, pIndex) => {
        log(`    ${pIndex + 1}. ${participant.displayName} (${participant.userId})`);
      });
    });

    log(`\n${colors.bright}=== MANUAL TESTING INSTRUCTIONS ===${colors.reset}`);
    log(`1. Start Flutter app: ${colors.cyan}./run.sh --flutter${colors.reset}`);
    log(`2. Open browser to: ${colors.blue}http://localhost:52778${colors.reset}`);
    log(`3. Click "Join Session" and enter one of the Session IDs above`);
    log(`4. Enter any display name and join the session`);
    log(`5. You should see the other participants listed above on the map`);
    log(`6. Repeat with different sessions to test multiple scenarios`);
    
    log(`\n${colors.bright}=== NEXT STEPS ===${colors.reset}`);
    log(`🚀 Location simulation will start automatically`);
    log(`📱 Open Flutter app: ${colors.cyan}http://localhost:52778${colors.reset}`);
    log(`💾 Session data (without tokens): ${colors.cyan}session-data-${results.scenario}.json${colors.reset}`);
  }
}

function saveSessionData(results) {
  try {
    const filename = `session-data-${results.scenario}.json`;
    const filepath = path.join(__dirname, filename);
    
    // SECURITY: Remove JWT tokens before saving to prevent token leakage
    const sanitizedResults = {
      ...results,
      sessions: results.sessions.map(session => ({
        ...session,
        participants: session.participants.map(participant => ({
          userId: participant.userId,
          displayName: participant.displayName
          // websocketToken is intentionally excluded for security
        }))
      }))
    };
    
    // Add timestamp and instructions for reference
    const dataToSave = {
      ...sanitizedResults,
      createdAt: new Date().toISOString(),
      simulatorInstructions: {
        command: `node location-simulator.js ${filename}`,
        description: "Run this command to simulate participant locations and movement",
        note: "JWT tokens are not saved to this file for security reasons"
      }
    };
    
    fs.writeFileSync(filepath, JSON.stringify(dataToSave, null, 2));
    logSuccess(`Session data saved to: ${filename} (tokens excluded for security)`);
  } catch (error) {
    logWarning(`Failed to save session data: ${error.message}`);
  }
}

async function checkBackendHealth() {
  try {
    logInfo('Checking backend health...');
    // Health endpoint is at /health, not /api/health
    const response = await fetch('http://localhost:4000/health');
    if (response.ok) {
      const data = await response.json();
      logSuccess(`Backend is running and healthy (${data.status})`);
      return true;
    } else {
      throw new Error(`Health check returned ${response.status}`);
    }
  } catch (error) {
    if (error.code === 'ECONNREFUSED') {
      logError('Cannot connect to backend. Make sure Elixir server is running on localhost:4000');
    } else {
      logError(`Backend health check failed: ${error.message}`);
    }
    return false;
  }
}

// CLI interface
function showUsage() {
  console.log(`
${colors.bright}API Session Creator${colors.reset}

${colors.cyan}USAGE:${colors.reset}
  node api-session-creator.js [scenario]

${colors.cyan}SCENARIOS:${colors.reset}
  basic     Create 2 sessions with 3 participants each (default)
  stress    Create 5 sessions with 8 participants each
  all       Run all scenarios

${colors.cyan}EXAMPLES:${colors.reset}
  node api-session-creator.js basic
  node api-session-creator.js stress
  node api-session-creator.js all

${colors.cyan}REQUIREMENTS:${colors.reset}
  - Elixir backend running on localhost:4000
  - Node.js with fetch support (Node 18+)

${colors.cyan}CONFIGURATION:${colors.reset}
  Edit ${CONFIG_FILE} to customize scenarios
`);
}

async function main() {
  const args = process.argv.slice(2);
  const scenario = args[0] || 'basic';

  if (scenario === '--help' || scenario === '-h') {
    showUsage();
    return;
  }

  try {
    // Check if backend is running
    const backendHealthy = await checkBackendHealth();
    if (!backendHealthy) {
      logError('Cannot proceed without healthy backend');
      logInfo('Start the backend with: ./run.sh --elixir');
      process.exit(1);
    }

    // Load configuration
    const config = loadConfig();

    if (scenario === 'all') {
      // Run all scenarios
      for (const scenarioName of Object.keys(config.scenarios)) {
        const results = await createTestScenario(scenarioName, config);
        displayResults(results);
        log('\n' + '='.repeat(60));
      }
    } else {
      // Run specific scenario
      if (!config.scenarios[scenario]) {
        logError(`Unknown scenario: ${scenario}`);
        logInfo('Available scenarios: ' + Object.keys(config.scenarios).join(', '));
        process.exit(1);
      }

      const results = await createTestScenario(scenario, config);
      displayResults(results);
      
      // Start location simulation with tokens (secure - no file storage)
      if (results.sessions.length > 0) {
        logInfo('\nStarting location simulation...');
        await startLocationSimulation(results);
      }
    }

  } catch (error) {
    logError(`Failed to create test scenario: ${error.message}`);
    process.exit(1);
  }
}

// Location simulation (embedded to avoid storing JWT tokens in files)
async function startLocationSimulation(results) {
  const WebSocket = require('ws');
  
  // Configuration for location simulation
  const UPDATE_INTERVAL = 2000; // 2 seconds
  const WS_BASE_URL = 'ws://localhost:4000/socket/websocket';
  
  const simulators = [];
  let allConnected = false;
  
  logInfo(`Creating ${results.summary.totalParticipants} location simulators...`);
  
  // Create simulators for each participant
  for (const session of results.sessions) {
    for (const participant of session.participants) {
      if (participant.websocketToken) {
        const simulator = new LocationSimulator(
          participant.userId,
          participant.displayName,
          session.sessionId,
          participant.websocketToken
        );
        simulators.push(simulator);
      }
    }
  }
  
  // Connect all simulators
  try {
    await Promise.all(simulators.map(sim => sim.connect()));
    allConnected = true;
    logSuccess(`✅ All ${simulators.length} simulators connected successfully!`);
    
    log(`\n${colors.bright}=== LOCATION SIMULATION ACTIVE ===${colors.reset}`);
    log(`🎯 Participants are now moving on the map`);
    log(`📱 Open Flutter app: ${colors.cyan}http://localhost:52778${colors.reset}`);
    log(`🔗 Join any session to see them moving in real-time`);
    log(`⏹️  Press Ctrl+C to stop simulation\n`);
    
    // Start location updates for all simulators
    simulators.forEach(sim => sim.startUpdates());
    
    // Keep the process alive
    process.on('SIGINT', () => {
      log('\n👋 Shutting down location simulators...');
      simulators.forEach(sim => sim.disconnect());
      process.exit(0);
    });
    
    // Keep running indefinitely
    await new Promise(() => {}); // Never resolves
    
  } catch (error) {
    logError(`Failed to start location simulation: ${error.message}`);
    simulators.forEach(sim => sim.disconnect());
  }
}

// Location Simulator Class
class LocationSimulator {
  constructor(userId, displayName, sessionId, websocketToken) {
    this.userId = userId;
    this.displayName = displayName;
    this.sessionId = sessionId;
    this.websocketToken = websocketToken;
    this.ws = null;
    this.updateInterval = null;
    this.connected = false;
    
    // Random starting location around San Francisco
    this.location = {
      latitude: 37.7749 + (Math.random() - 0.5) * 0.01,
      longitude: -122.4194 + (Math.random() - 0.5) * 0.01
    };
    
    // Random movement pattern
    this.movementPattern = Math.random() < 0.5 ? 'circular' : 'linear';
    this.speed = 0.0001 + Math.random() * 0.0001; // Degrees per update
    this.direction = Math.random() * 2 * Math.PI;
  }
  
  async connect() {
    return new Promise((resolve, reject) => {
      try {
        // Build WebSocket URL with authentication
        const wsUrl = `${WS_BASE_URL}?token=${encodeURIComponent(this.websocketToken)}&session_id=${this.sessionId}&user_id=${this.userId}`;
        
        this.ws = new WebSocket(wsUrl);
        
        this.ws.on('open', () => {
          // Join the location channel
          const joinMessage = {
            topic: `location:${this.sessionId}`,
            event: 'phx_join',
            payload: {},
            ref: Date.now().toString()
          };
          
          this.ws.send(JSON.stringify(joinMessage));
          this.connected = true;
          logSuccess(`🔗 ${this.displayName} connected`);
          resolve();
        });
        
        this.ws.on('error', (error) => {
          logError(`❌ ${this.displayName} connection failed: ${error.message}`);
          reject(error);
        });
        
        this.ws.on('close', () => {
          this.connected = false;
          if (this.updateInterval) {
            clearInterval(this.updateInterval);
          }
        });
        
      } catch (error) {
        reject(error);
      }
    });
  }
  
  startUpdates() {
    if (!this.connected || this.updateInterval) return;
    
    this.updateInterval = setInterval(() => {
      this.updateLocation();
      this.broadcastLocation();
    }, UPDATE_INTERVAL);
  }
  
  updateLocation() {
    if (this.movementPattern === 'circular') {
      // Circular movement
      this.direction += 0.1;
      this.location.latitude += Math.cos(this.direction) * this.speed;
      this.location.longitude += Math.sin(this.direction) * this.speed;
    } else {
      // Linear movement with random direction changes
      if (Math.random() < 0.1) { // 10% chance to change direction
        this.direction = Math.random() * 2 * Math.PI;
      }
      this.location.latitude += Math.cos(this.direction) * this.speed;
      this.location.longitude += Math.sin(this.direction) * this.speed;
    }
  }
  
  broadcastLocation() {
    if (!this.connected || !this.ws) return;
    
    const locationMessage = {
      topic: `location:${this.sessionId}`,
      event: 'location_update',
      payload: {
        user_id: this.userId,
        latitude: this.location.latitude,
        longitude: this.location.longitude,
        timestamp: new Date().toISOString()
      },
      ref: Date.now().toString()
    };
    
    this.ws.send(JSON.stringify(locationMessage));
  }
  
  disconnect() {
    this.connected = false;
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = {
  createSession,
  addParticipant,
  getSessionDetails,
  getParticipants,
  createTestScenario
};