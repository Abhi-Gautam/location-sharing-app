import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';
import http from 'k6/http';

// Custom metrics for multi-session testing
const wsConnectionRate = new Rate('websocket_connection_success');
const wsMessageSendRate = new Rate('websocket_message_send_success');
const wsConnectionDuration = new Trend('websocket_connecting_duration');
const wsMessageSendDuration = new Trend('websocket_message_send_duration');
const locationUpdatesCounter = new Counter('location_updates_sent');
const participantJoinCounter = new Counter('participant_joins');
const sessionCreationCounter = new Counter('sessions_created');
const activeSessionsGauge = new Gauge('active_sessions_count');
const messagesReceivedCounter = new Counter('messages_received');
const broadcastLatency = new Trend('broadcast_latency');

// Load test configuration
const CONFIG = JSON.parse(open('../config/test-scenarios.json'));

// Test parameters
const BACKEND = __ENV.BACKEND || 'rust';
const SCENARIO = __ENV.SCENARIO || 'multi_session_load';
const API_URL = __ENV.API_URL || CONFIG.backends[BACKEND].api_url;
const WS_URL = __ENV.WS_URL || CONFIG.backends[BACKEND].ws_url;

const scenario = CONFIG.scenarios[SCENARIO];

export const options = {
  scenarios: {
    multi_session_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: scenario.rampUp, target: scenario.users },
        { duration: scenario.duration, target: scenario.users },
        { duration: '2m', target: 0 },
      ],
    },
  },
  thresholds: {
    ...CONFIG.thresholds,
    'websocket_connection_success': ['rate>0.95'],
    'websocket_message_send_success': ['rate>0.98'],
    'broadcast_latency': ['p95<500'],
  },
};

// Realistic movement patterns
const MOVEMENT_PATTERNS = {
  walking: { speed: 0.0001, variance: 0.00005 }, // ~5 km/h
  driving: { speed: 0.0005, variance: 0.0002 },  // ~30 km/h
  stationary: { speed: 0.00001, variance: 0.000005 }, // GPS drift
};

// City boundaries for realistic location generation
const CITIES = [
  { name: 'San Francisco', lat: 37.7749, lng: -122.4194, radius: 0.05 },
  { name: 'New York', lat: 40.7128, lng: -74.0060, radius: 0.08 },
  { name: 'Los Angeles', lat: 34.0522, lng: -118.2437, radius: 0.1 },
  { name: 'Chicago', lat: 41.8781, lng: -87.6298, radius: 0.06 },
  { name: 'Houston', lat: 29.7604, lng: -95.3698, radius: 0.07 },
];

// Test data generators
function generateSessionName() {
  const prefixes = ['MultiStorm', 'ConcurrentFlood', 'ParallelWave', 'SyncTsunami', 'MegaSession'];
  const activities = ['Test', 'Load', 'Stress', 'Burst', 'Chaos'];
  const numbers = Math.floor(Math.random() * 10000);
  return `${prefixes[Math.floor(Math.random() * prefixes.length)]} ${activities[Math.floor(Math.random() * activities.length)]} ${numbers}`;
}

function generateUserName() {
  const firstNames = ['Multi', 'Sync', 'Async', 'Parallel', 'Concurrent', 'Distributed', 'Virtual', 'Sim'];
  const lastNames = ['User', 'Client', 'Tester', 'Agent', 'Worker', 'Instance', 'Unit', 'Node'];
  return `${firstNames[Math.floor(Math.random() * firstNames.length)]} ${lastNames[Math.floor(Math.random() * lastNames.length)]} ${__VU}`;
}

function generateLocation(city, pattern = 'walking') {
  const movement = MOVEMENT_PATTERNS[pattern];
  const baseRange = city.radius;
  
  return {
    latitude: city.lat + (Math.random() - 0.5) * baseRange,
    longitude: city.lng + (Math.random() - 0.5) * baseRange,
    movement: movement,
  };
}

function generateAvatarColor() {
  const colors = [
    '#FF5733', '#33FF57', '#3357FF', '#FF33F1', '#F1FF33', '#33FFF1',
    '#FF8C33', '#8C33FF', '#33FF8C', '#FF3333', '#3333FF', '#FFFF33',
    '#C70039', '#900C3F', '#581845', '#FFC300', '#DAF7A6', '#FF5733'
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Multi-session management
function createMultipleSessions(sessionCount) {
  const sessions = [];
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  for (let i = 0; i < sessionCount; i++) {
    const sessionPayload = {
      name: generateSessionName(),
      expires_in_minutes: 180, // Longer for stress tests
    };

    const sessionResponse = http.post(
      `${API_URL}/api/sessions`,
      JSON.stringify(sessionPayload),
      { headers }
    );

    if (sessionResponse.status === 200 || sessionResponse.status === 201) {
      const sessionData = JSON.parse(sessionResponse.body);
      sessions.push({
        id: sessionData.session_id,
        name: sessionData.name,
        city: CITIES[i % CITIES.length], // Distribute across cities
      });
      sessionCreationCounter.add(1);
    }
  }

  activeSessionsGauge.add(sessions.length);
  return sessions;
}

function joinRandomSession(sessions) {
  if (sessions.length === 0) return null;
  
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  const selectedSession = sessions[Math.floor(Math.random() * sessions.length)];
  const joinPayload = {
    display_name: generateUserName(),
    avatar_color: generateAvatarColor(),
  };

  const joinResponse = http.post(
    `${API_URL}/api/sessions/${selectedSession.id}/join`,
    JSON.stringify(joinPayload),
    { headers }
  );

  if (joinResponse.status === 200 || joinResponse.status === 201) {
    const joinData = JSON.parse(joinResponse.body);
    return {
      sessionId: selectedSession.id,
      sessionName: selectedSession.name,
      city: selectedSession.city,
      userId: joinData.user_id,
      wsToken: joinData.websocket_token,
    };
  }

  return null;
}

// Enhanced location simulation with realistic movement
function simulateLocationMovement(initialLocation, pattern = 'walking') {
  const movement = MOVEMENT_PATTERNS[pattern];
  let currentLocation = { ...initialLocation };

  return function getNextLocation() {
    // Add realistic movement based on pattern
    const deltaLat = (Math.random() - 0.5) * movement.speed;
    const deltaLng = (Math.random() - 0.5) * movement.speed;
    
    currentLocation.latitude += deltaLat + (Math.random() - 0.5) * movement.variance;
    currentLocation.longitude += deltaLng + (Math.random() - 0.5) * movement.variance;

    return {
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      timestamp: new Date().toISOString(),
    };
  };
}

// Main test function
export default function () {
  console.log(`[VU ${__VU}] Starting multi-session WebSocket stress test...`);
  
  // Create multiple sessions for this VU to participate in
  const sessionsPerVU = Math.floor(scenario.sessions_per_vu) || 2;
  const sessions = createMultipleSessions(sessionsPerVU);
  
  if (sessions.length === 0) {
    console.error(`[VU ${__VU}] Failed to create any sessions, aborting`);
    return;
  }

  console.log(`[VU ${__VU}] Created ${sessions.length} sessions`);

  // Join a random session
  const sessionInfo = joinRandomSession(sessions);
  if (!sessionInfo) {
    console.error(`[VU ${__VU}] Failed to join any session, aborting`);
    return;
  }

  const { sessionId, userId, wsToken, city, sessionName } = sessionInfo;
  console.log(`[VU ${__VU}] Joined session: ${sessionName} in ${city.name}`);

  // Prepare WebSocket URL with authentication
  let wsUrl;
  if (BACKEND === 'rust') {
    wsUrl = `${WS_URL}/ws?session_id=${sessionId}&user_id=${userId}&token=${wsToken}`;
  } else {
    // Elixir Phoenix Channels
    wsUrl = `${WS_URL}?session_id=${sessionId}&user_id=${userId}&token=${wsToken}`;
  }

  console.log(`[VU ${__VU}] Connecting to WebSocket: ${wsUrl}`);

  // WebSocket connection test with enhanced monitoring
  const connectStart = Date.now();
  
  const response = ws.connect(wsUrl, {}, function (socket) {
    const connectDuration = Date.now() - connectStart;
    wsConnectionDuration.add(connectDuration);
    
    console.log(`[VU ${__VU}] WebSocket connected in ${connectDuration}ms`);
    wsConnectionRate.add(true);
    participantJoinCounter.add(1);

    // Initialize location tracking
    const movementPattern = ['walking', 'driving', 'stationary'][Math.floor(Math.random() * 3)];
    const initialLocation = generateLocation(city, movementPattern);
    const locationSimulator = simulateLocationMovement(initialLocation, movementPattern);
    
    console.log(`[VU ${__VU}] Using ${movementPattern} movement pattern`);

    // Track message latency by storing send timestamps
    const messageLatencyMap = new Map();

    // Handle incoming messages with latency tracking
    socket.on('message', function (message) {
      const receiveTime = Date.now();
      messagesReceivedCounter.add(1);
      
      try {
        const data = JSON.parse(message);
        console.log(`[VU ${__VU}] Received: ${data.type || 'unknown'}`);
        
        // Track broadcast latency for location updates
        if (data.type === 'location_update' && data.data && data.data.timestamp) {
          const messageTime = new Date(data.data.timestamp).getTime();
          const latency = receiveTime - messageTime;
          if (latency > 0 && latency < 10000) { // Sanity check: latency < 10s
            broadcastLatency.add(latency);
          }
        }
        
        // Track response latency for sent messages
        if (data.ref && messageLatencyMap.has(data.ref)) {
          const sendTime = messageLatencyMap.get(data.ref);
          const latency = receiveTime - sendTime;
          wsMessageSendDuration.add(latency);
          messageLatencyMap.delete(data.ref);
        }
      } catch (e) {
        console.log(`[VU ${__VU}] Received non-JSON: ${message.substring(0, 100)}...`);
      }
    });

    socket.on('error', function (e) {
      console.error(`[VU ${__VU}] WebSocket error: ${e.error()}`);
    });

    socket.on('close', function () {
      console.log(`[VU ${__VU}] WebSocket closed`);
    });

    // Send initial presence/join message
    let joinMessage;
    const joinRef = `join_${Date.now()}_${__VU}`;
    
    if (BACKEND === 'rust') {
      joinMessage = JSON.stringify({
        type: 'join_session',
        data: {
          session_id: sessionId,
          user_id: userId
        },
        ref: joinRef
      });
    } else {
      // Phoenix Channels format
      joinMessage = JSON.stringify({
        topic: `session:${sessionId}`,
        event: 'phx_join',
        payload: {
          user_id: userId
        },
        ref: joinRef
      });
    }

    const joinStart = Date.now();
    messageLatencyMap.set(joinRef, joinStart);
    socket.send(joinMessage);
    wsMessageSendRate.add(true);

    // Enhanced location update frequency based on scenario and movement pattern
    const baseFrequency = scenario.location_updates_per_second || 1;
    const patternMultiplier = movementPattern === 'driving' ? 2 : movementPattern === 'stationary' ? 0.5 : 1;
    const updateFrequency = baseFrequency * patternMultiplier;
    const updateInterval = 1000 / updateFrequency; // milliseconds

    // Send location updates with realistic patterns
    let updateCount = 0;
    const maxUpdates = Math.floor((scenario.duration.replace('m', '') * 60) / (updateInterval / 1000));
    
    const updateTimer = setInterval(() => {
      if (updateCount >= maxUpdates) {
        clearInterval(updateTimer);
        socket.close();
        return;
      }

      const location = locationSimulator();
      const updateRef = `update_${Date.now()}_${__VU}_${updateCount}`;
      let locationMessage;

      if (BACKEND === 'rust') {
        locationMessage = JSON.stringify({
          type: 'location_update',
          data: {
            session_id: sessionId,
            user_id: userId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: location.timestamp
          },
          ref: updateRef
        });
      } else {
        // Phoenix Channels format
        locationMessage = JSON.stringify({
          topic: `session:${sessionId}`,
          event: 'location_update',
          payload: {
            user_id: userId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: location.timestamp
          },
          ref: updateRef
        });
      }

      const sendStart = Date.now();
      messageLatencyMap.set(updateRef, sendStart);
      socket.send(locationMessage);
      wsMessageSendRate.add(true);
      locationUpdatesCounter.add(1);
      
      updateCount++;
      
      if (updateCount % 50 === 0) {
        console.log(`[VU ${__VU}] Sent ${updateCount} location updates (${movementPattern} pattern)`);
      }
    }, updateInterval);

    // Simulate random participant behavior
    const behaviorTimer = setInterval(() => {
      // Randomly simulate joining other sessions (if configured)
      if (Math.random() < 0.1 && sessions.length > 1) { // 10% chance
        const otherSessions = sessions.filter(s => s.id !== sessionId);
        if (otherSessions.length > 0) {
          const newSession = joinRandomSession(otherSessions);
          if (newSession) {
            console.log(`[VU ${__VU}] Simulated joining additional session: ${newSession.sessionName}`);
          }
        }
      }
    }, 30000); // Check every 30 seconds

    // Handle test duration
    setTimeout(() => {
      clearInterval(updateTimer);
      clearInterval(behaviorTimer);
      console.log(`[VU ${__VU}] Test duration reached, closing connection`);
      socket.close();
    }, (parseInt(scenario.duration.replace('m', '')) * 60 + 30) * 1000); // Add 30s buffer
  });

  // Check connection result
  check(response, {
    'websocket connection established': (r) => r && r.status === 101,
  });

  if (!response || response.status !== 101) {
    console.error(`[VU ${__VU}] WebSocket connection failed: ${response ? response.status : 'unknown'}`);
    wsConnectionRate.add(false);
    return;
  }

  // Keep the test running for the scenario duration
  sleep(parseInt(scenario.duration.replace('m', '')) * 60 + 60); // Add 1 minute buffer
}

// Setup function
export function setup() {
  console.log(`Starting ${SCENARIO} multi-session WebSocket test against ${BACKEND} backend`);
  console.log(`API URL: ${API_URL}`);
  console.log(`WebSocket URL: ${WS_URL}`);
  console.log(`Target Users: ${scenario.users}`);
  console.log(`Duration: ${scenario.duration}`);
  console.log(`Sessions per VU: ${scenario.sessions_per_vu || 2}`);
  
  if (scenario.location_updates_per_second) {
    console.log(`Base Location Updates per Second: ${scenario.location_updates_per_second}`);
  }

  // Health check
  const healthResponse = http.get(`${API_URL}${CONFIG.backends[BACKEND].health_endpoint}`);
  if (healthResponse.status !== 200) {
    throw new Error(`Backend health check failed: ${healthResponse.status}`);
  }
  
  console.log('Backend health check passed');
  console.log('WARNING: This test will create MANY sessions and WebSocket connections');
  console.log('WARNING: This will generate HIGH Redis pub/sub load across multiple channels');
  
  return { backend: BACKEND, scenario: SCENARIO };
}

// Teardown function
export function teardown(data) {
  console.log(`Multi-session WebSocket stress test completed for ${data.backend} backend`);
  console.log(`Scenario: ${data.scenario}`);
  console.log('Check Prometheus/Grafana for detailed Redis and WebSocket metrics');
  console.log('Pay special attention to:');
  console.log('- Redis pub/sub channel performance');
  console.log('- WebSocket connection pool utilization');
  console.log('- Cross-session message broadcast latency');
  console.log('- Memory usage patterns');
}