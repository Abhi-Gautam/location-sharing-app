import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import http from 'k6/http';

// Custom metrics for location flood testing
const locationUpdateRate = new Rate('location_update_success');
const locationUpdateDuration = new Trend('location_update_duration');
const locationUpdatesCounter = new Counter('total_location_updates');
const wsConnectionRate = new Rate('websocket_connection_success');
const wsConnectionDuration = new Trend('websocket_connection_duration');
const participantCounter = new Counter('active_participants');
const sessionCounter = new Counter('active_sessions');

// Load test configuration
const CONFIG = JSON.parse(open('../config/test-scenarios.json'));

// Test parameters
const BACKEND = __ENV.BACKEND || 'rust';
const SCENARIO = __ENV.SCENARIO || 'location_update_flood';
const API_URL = __ENV.API_URL || CONFIG.backends[BACKEND].api_url;
const WS_URL = __ENV.WS_URL || CONFIG.backends[BACKEND].ws_url;

const scenario = CONFIG.scenarios[SCENARIO];

export const options = {
  scenarios: {
    location_flood: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: scenario.rampUp, target: scenario.users },
        { duration: scenario.duration, target: scenario.users },
        { duration: '1m', target: 0 },
      ],
    },
  },
  thresholds: {
    ...CONFIG.thresholds,
    'location_update_success': ['rate>0.95'],
    'location_update_duration': ['p(95)<100', 'p(99)<200'],
  },
};

// Enhanced location generators for realistic movement patterns
class LocationGenerator {
  constructor(startLat, startLng, movementPattern = 'random_walk') {
    this.currentLat = startLat;
    this.currentLng = startLng;
    this.pattern = movementPattern;
    this.speed = 0.0001; // ~10 meters per update
    this.direction = Math.random() * 2 * Math.PI;
    this.boundaryRadius = 0.01; // ~1km radius
    this.centerLat = startLat;
    this.centerLng = startLng;
  }

  nextLocation() {
    switch (this.pattern) {
      case 'random_walk':
        return this.randomWalk();
      case 'circular':
        return this.circular();
      case 'linear':
        return this.linear();
      case 'stationary':
        return this.stationary();
      default:
        return this.randomWalk();
    }
  }

  randomWalk() {
    // Random walk with momentum
    this.direction += (Math.random() - 0.5) * 0.5; // Small direction changes
    
    const deltaLat = Math.sin(this.direction) * this.speed;
    const deltaLng = Math.cos(this.direction) * this.speed;
    
    this.currentLat += deltaLat;
    this.currentLng += deltaLng;
    
    // Boundary check - bounce back if too far from center
    const distanceFromCenter = Math.sqrt(
      Math.pow(this.currentLat - this.centerLat, 2) + 
      Math.pow(this.currentLng - this.centerLng, 2)
    );
    
    if (distanceFromCenter > this.boundaryRadius) {
      this.direction += Math.PI; // Reverse direction
    }
    
    return {
      latitude: this.currentLat,
      longitude: this.currentLng,
    };
  }

  circular() {
    // Circular movement around center point
    this.direction += 0.1; // Constant angular velocity
    
    const radius = this.boundaryRadius * 0.5;
    this.currentLat = this.centerLat + Math.sin(this.direction) * radius;
    this.currentLng = this.centerLng + Math.cos(this.direction) * radius;
    
    return {
      latitude: this.currentLat,
      longitude: this.currentLng,
    };
  }

  linear() {
    // Linear movement with occasional direction changes
    if (Math.random() < 0.05) { // 5% chance to change direction
      this.direction = Math.random() * 2 * Math.PI;
    }
    
    const deltaLat = Math.sin(this.direction) * this.speed;
    const deltaLng = Math.cos(this.direction) * this.speed;
    
    this.currentLat += deltaLat;
    this.currentLng += deltaLng;
    
    return {
      latitude: this.currentLat,
      longitude: this.currentLng,
    };
  }

  stationary() {
    // Stationary with small GPS noise
    const noise = 0.00001; // ~1 meter GPS noise
    return {
      latitude: this.currentLat + (Math.random() - 0.5) * noise,
      longitude: this.currentLng + (Math.random() - 0.5) * noise,
    };
  }
}

// Generate realistic starting locations around major cities
function generateStartingLocation() {
  const cities = [
    { name: 'San Francisco', lat: 37.7749, lng: -122.4194 },
    { name: 'New York', lat: 40.7128, lng: -74.0060 },
    { name: 'Los Angeles', lat: 34.0522, lng: -118.2437 },
    { name: 'Chicago', lat: 41.8781, lng: -87.6298 },
    { name: 'Houston', lat: 29.7604, lng: -95.3698 },
    { name: 'Phoenix', lat: 33.4484, lng: -112.0740 },
    { name: 'Philadelphia', lat: 39.9526, lng: -75.1652 },
    { name: 'San Antonio', lat: 29.4241, lng: -98.4936 },
  ];
  
  const city = cities[Math.floor(Math.random() * cities.length)];
  const range = 0.05; // ~5km radius around city center
  
  return {
    latitude: city.lat + (Math.random() - 0.5) * range,
    longitude: city.lng + (Math.random() - 0.5) * range,
  };
}

function generateMovementPattern() {
  const patterns = ['random_walk', 'circular', 'linear', 'stationary'];
  const weights = [0.4, 0.2, 0.3, 0.1]; // Probability weights
  
  const random = Math.random();
  let cumulative = 0;
  
  for (let i = 0; i < patterns.length; i++) {
    cumulative += weights[i];
    if (random < cumulative) {
      return patterns[i];
    }
  }
  
  return 'random_walk';
}

function generateUserName() {
  const adjectives = ['Swift', 'Mobile', 'Active', 'Dynamic', 'Rapid', 'Quick', 'Fast', 'Agile'];
  const nouns = ['User', 'Mover', 'Traveler', 'Explorer', 'Walker', 'Runner', 'Driver', 'Rider'];
  return `${adjectives[Math.floor(Math.random() * adjectives.length)]} ${nouns[Math.floor(Math.random() * nouns.length)]} ${__VU}`;
}

function generateAvatarColor() {
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD',
    '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9', '#F8C471', '#82E0AA'
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Session management for flood testing
function createSessionAndJoin() {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Create session
  const sessionPayload = {
    name: `Location Flood Test Session ${Math.floor(Math.random() * 10000)}`,
    expires_in_minutes: 180, // 3 hours for long flood tests
  };

  const sessionResponse = http.post(
    `${API_URL}/api/sessions`,
    JSON.stringify(sessionPayload),
    { headers }
  );

  if (sessionResponse.status !== 201) {
    return null;
  }

  const sessionData = JSON.parse(sessionResponse.body);
  sessionCounter.add(1);

  // Join session
  const joinPayload = {
    display_name: generateUserName(),
    avatar_color: generateAvatarColor(),
  };

  const joinResponse = http.post(
    `${API_URL}/api/sessions/${sessionData.session_id}/join`,
    JSON.stringify(joinPayload),
    { headers }
  );

  if (joinResponse.status !== 201) {
    return null;
  }

  const joinData = JSON.parse(joinResponse.body);
  participantCounter.add(1);

  return {
    sessionId: sessionData.session_id,
    userId: joinData.user_id,
    wsToken: joinData.websocket_token,
  };
}

// Main test function
export default function () {
  console.log(`[VU ${__VU}] Starting location flood test...`);
  
  // Setup session
  const sessionInfo = createSessionAndJoin();
  if (!sessionInfo) {
    console.error(`[VU ${__VU}] Failed to setup session`);
    return;
  }

  const { sessionId, userId, wsToken } = sessionInfo;

  // Initialize location generator
  const startLocation = generateStartingLocation();
  const movementPattern = generateMovementPattern();
  const locationGen = new LocationGenerator(
    startLocation.latitude,
    startLocation.longitude,
    movementPattern
  );

  console.log(`[VU ${__VU}] Using ${movementPattern} movement pattern`);

  // Setup WebSocket connection
  let wsUrl;
  if (BACKEND === 'rust') {
    wsUrl = `${WS_URL}/ws?session_id=${sessionId}&user_id=${userId}&token=${wsToken}`;
  } else {
    wsUrl = `${WS_URL}?session_id=${sessionId}&user_id=${userId}&token=${wsToken}`;
  }

  const connectStart = Date.now();
  
  const response = ws.connect(wsUrl, {}, function (socket) {
    const connectDuration = Date.now() - connectStart;
    wsConnectionDuration.add(connectDuration);
    wsConnectionRate.add(true);
    
    console.log(`[VU ${__VU}] WebSocket connected in ${connectDuration}ms`);

    // Message handlers
    socket.on('message', function (message) {
      // Handle incoming location updates and other messages
      try {
        const data = JSON.parse(message);
        if (data.type === 'location_update' || data.event === 'location_update') {
          // Track received location updates for analysis
        }
      } catch (e) {
        // Handle non-JSON messages
      }
    });

    socket.on('error', function (e) {
      console.error(`[VU ${__VU}] WebSocket error: ${e.error()}`);
    });

    // Send initial join message
    let joinMessage;
    if (BACKEND === 'rust') {
      joinMessage = JSON.stringify({
        type: 'join_session',
        data: {
          session_id: sessionId,
          user_id: userId
        }
      });
    } else {
      joinMessage = JSON.stringify({
        topic: `session:${sessionId}`,
        event: 'phx_join',
        payload: { user_id: userId },
        ref: `join_${Date.now()}`
      });
    }

    socket.send(joinMessage);

    // Location update flood configuration
    const updatesPerSecond = scenario.location_updates_per_second || 10;
    const updateInterval = 1000 / updatesPerSecond;
    const testDurationMs = parseInt(scenario.duration.replace('m', '')) * 60 * 1000;
    const maxUpdates = Math.floor(testDurationMs / updateInterval);
    
    console.log(`[VU ${__VU}] Sending ${updatesPerSecond} location updates/second for ${scenario.duration}`);

    let updateCount = 0;
    const updateTimer = setInterval(() => {
      if (updateCount >= maxUpdates) {
        clearInterval(updateTimer);
        socket.close();
        return;
      }

      const location = locationGen.nextLocation();
      let locationMessage;

      if (BACKEND === 'rust') {
        locationMessage = JSON.stringify({
          type: 'location_update',
          data: {
            session_id: sessionId,
            user_id: userId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: new Date().toISOString(),
            accuracy: Math.random() * 10 + 5, // 5-15 meter accuracy
            heading: locationGen.direction * 180 / Math.PI, // Convert to degrees
            speed: Math.random() * 20 + 5, // 5-25 km/h
          }
        });
      } else {
        locationMessage = JSON.stringify({
          topic: `session:${sessionId}`,
          event: 'location_update',
          payload: {
            user_id: userId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: new Date().toISOString(),
            accuracy: Math.random() * 10 + 5,
            heading: locationGen.direction * 180 / Math.PI,
            speed: Math.random() * 20 + 5,
          },
          ref: `update_${Date.now()}_${updateCount}`
        });
      }

      const sendStart = Date.now();
      socket.send(locationMessage);
      const sendDuration = Date.now() - sendStart;
      
      locationUpdateDuration.add(sendDuration);
      locationUpdateRate.add(true);
      locationUpdatesCounter.add(1);
      
      updateCount++;
      
      // Log progress every 100 updates
      if (updateCount % 100 === 0) {
        console.log(`[VU ${__VU}] Progress: ${updateCount}/${maxUpdates} updates (${(updateCount/maxUpdates*100).toFixed(1)}%)`);
      }
    }, updateInterval);

    // Safety timeout
    setTimeout(() => {
      clearInterval(updateTimer);
      socket.close();
    }, testDurationMs + 10000); // 10 second buffer
  });

  // Verify connection
  check(response, {
    'websocket connection established': (r) => r && r.status === 101,
  });

  if (!response || response.status !== 101) {
    console.error(`[VU ${__VU}] WebSocket connection failed`);
    wsConnectionRate.add(false);
    return;
  }

  // Wait for test completion
  const testDurationSeconds = parseInt(scenario.duration.replace('m', '')) * 60;
  sleep(testDurationSeconds + 30); // 30 second buffer
}

// Setup function
export function setup() {
  console.log(`Starting Location Flood Test - ${SCENARIO}`);
  console.log(`Backend: ${BACKEND}`);
  console.log(`API URL: ${API_URL}`);
  console.log(`WebSocket URL: ${WS_URL}`);
  console.log(`Target Users: ${scenario.users}`);
  console.log(`Updates per User per Second: ${scenario.location_updates_per_second || 10}`);
  console.log(`Test Duration: ${scenario.duration}`);
  
  const totalUpdatesPerSecond = scenario.users * (scenario.location_updates_per_second || 10);
  console.log(`Total System Load: ${totalUpdatesPerSecond} location updates/second`);
  
  // Health check
  const healthResponse = http.get(`${API_URL}${CONFIG.backends[BACKEND].health_endpoint}`);
  if (healthResponse.status !== 200) {
    throw new Error(`Backend health check failed: ${healthResponse.status}`);
  }
  
  console.log('Backend health check passed');
  console.log('⚠️  WARNING: This test generates extremely high load!');
  console.log('⚠️  Monitor system resources closely during execution');
  
  return { 
    backend: BACKEND, 
    scenario: SCENARIO,
    expectedTotalUpdates: totalUpdatesPerSecond * parseInt(scenario.duration.replace('m', '')) * 60
  };
}

// Teardown function
export function teardown(data) {
  console.log(`Location Flood Test completed for ${data.backend} backend`);
  console.log(`Expected total location updates: ${data.expectedTotalUpdates}`);
  console.log('Check metrics in Prometheus/Grafana for actual throughput');
}