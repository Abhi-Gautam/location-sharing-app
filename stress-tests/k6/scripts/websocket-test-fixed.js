import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import http from 'k6/http';

// Custom metrics
const wsConnectionRate = new Rate('websocket_connection_success');
const wsMessageSendRate = new Rate('websocket_message_send_success');
const wsConnectionDuration = new Trend('websocket_connecting_duration');
const wsMessageSendDuration = new Trend('websocket_message_send_duration');
const locationUpdatesCounter = new Counter('location_updates_sent');
const participantJoinCounter = new Counter('participant_joins');

// Load test configuration
const CONFIG = JSON.parse(open('../config/test-scenarios.json'));

// Test parameters
const BACKEND = __ENV.BACKEND || 'rust';
const SCENARIO = __ENV.SCENARIO || 'baseline';
const API_URL = __ENV.API_URL || CONFIG.backends[BACKEND].api_url;
const WS_URL = __ENV.WS_URL || CONFIG.backends[BACKEND].ws_url;

const scenario = CONFIG.scenarios[SCENARIO];

export const options = {
  scenarios: {
    websocket_test: {
      executor: 'per-vu-iterations',
      vus: scenario.users,
      iterations: 1, // Each user does exactly 1 iteration
      maxDuration: '2m', // Safety timeout
    },
  },
  thresholds: {
    ...CONFIG.thresholds,
    'websocket_connection_success': ['rate>0.95'],
    'websocket_message_send_success': ['rate>0.98'],
  },
};

// Test data generators
function generateSessionName() {
  const prefixes = ['Test', 'Load', 'Stress'];
  const numbers = Math.floor(Math.random() * 1000);
  return `${prefixes[Math.floor(Math.random() * prefixes.length)]} ${numbers}`;
}

function generateUserName() {
  const names = ['TestUser', 'LoadUser', 'StressUser'];
  return `${names[Math.floor(Math.random() * names.length)]} ${__VU}`;
}

function generateLocation() {
  // Generate random locations around San Francisco
  const baseLat = 37.7749;
  const baseLng = -122.4194;
  const range = 0.01; // roughly 1km radius
  
  return {
    latitude: baseLat + (Math.random() - 0.5) * range,
    longitude: baseLng + (Math.random() - 0.5) * range,
    accuracy: Math.random() * 10 + 1, // 1-11 meters
    timestamp: new Date().toISOString()
  };
}

function generateAvatarColor() {
  const colors = ['#FF5733', '#33FF57', '#3357FF', '#FF33F1', '#F1FF33', '#33FFF1'];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Global session storage
let globalSessions = [];

// Session setup helper
function createSessionAndJoin() {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  let sessionId;
  
  // Check if we're using shared sessions (massive_scale scenario)
  if (scenario.sessions && scenario.users_per_session) {
    // Use shared sessions: map VU to one of the pre-created sessions
    const sessionIndex = (__VU - 1) % scenario.sessions;
    
    if (globalSessions[sessionIndex]) {
      sessionId = globalSessions[sessionIndex];
    } else {
      // Create session if it doesn't exist yet
      const sessionPayload = {
        name: `SharedSession_${sessionIndex + 1}`,
        expires_in_minutes: 60,
      };

      const sessionResponse = http.post(
        `${API_URL}/api/sessions`,
        JSON.stringify(sessionPayload),
        { headers }
      );

      if (sessionResponse.status !== 200 && sessionResponse.status !== 201) {
        console.error(`[VU ${__VU}] Failed to create shared session: ${sessionResponse.status}`);
        return null;
      }

      const sessionData = JSON.parse(sessionResponse.body);
      sessionId = sessionData.session_id;
      globalSessions[sessionIndex] = sessionId;
      console.log(`[VU ${__VU}] Created shared session ${sessionIndex + 1}: ${sessionId}`);
    }
  } else {
    // Original behavior: each user creates their own session
    const sessionPayload = {
      name: `${generateSessionName()}_VU${__VU}`,
      expires_in_minutes: 60,
    };

    const sessionResponse = http.post(
      `${API_URL}/api/sessions`,
      JSON.stringify(sessionPayload),
      { headers }
    );

    if (sessionResponse.status !== 200 && sessionResponse.status !== 201) {
      console.error(`[VU ${__VU}] Failed to create session: ${sessionResponse.status}`);
      return null;
    }

    const sessionData = JSON.parse(sessionResponse.body);
    sessionId = sessionData.session_id;
  }

  // Join the session
  const joinPayload = {
    display_name: generateUserName(),
    avatar_color: generateAvatarColor(),
  };

  const joinResponse = http.post(
    `${API_URL}/api/sessions/${sessionId}/join`,
    JSON.stringify(joinPayload),
    { headers }
  );

  if (joinResponse.status !== 200 && joinResponse.status !== 201) {
    console.error(`[VU ${__VU}] Failed to join session: ${joinResponse.status}`);
    return null;
  }

  const joinData = JSON.parse(joinResponse.body);
  
  return {
    sessionId,
    userId: joinData.user_id,
    wsToken: joinData.websocket_token,
  };
}

// Main test function
export default function () {
  const isSharedSession = scenario.sessions && scenario.users_per_session;
  const sessionIndex = isSharedSession ? ((__VU - 1) % scenario.sessions) + 1 : 'individual';
  
  console.log(`[VU ${__VU}] Starting WebSocket test for ${BACKEND} backend${isSharedSession ? ` (shared session ${sessionIndex})` : ''}...`);
  
  // Setup session
  const sessionInfo = createSessionAndJoin();
  if (!sessionInfo) {
    console.error(`[VU ${__VU}] Failed to setup session, aborting`);
    return;
  }

  const { sessionId, userId, wsToken } = sessionInfo;
  console.log(`[VU ${__VU}] Session setup complete: ${sessionId}${isSharedSession ? ` (session ${sessionIndex})` : ''}`);

  // Prepare WebSocket URL with authentication
  let wsUrl;
  if (BACKEND === 'rust') {
    wsUrl = `${WS_URL}/ws?token=${wsToken}`;
  } else {
    // Elixir Phoenix Channels
    wsUrl = `${WS_URL}?token=${wsToken}`;
  }

  console.log(`[VU ${__VU}] Connecting to WebSocket: ${wsUrl}`);

  // WebSocket connection test
  const connectStart = Date.now();
  
  const response = ws.connect(wsUrl, {}, function (socket) {
    const connectDuration = Date.now() - connectStart;
    wsConnectionDuration.add(connectDuration);
    
    console.log(`[VU ${__VU}] WebSocket connected in ${connectDuration}ms`);
    wsConnectionRate.add(true);
    participantJoinCounter.add(1);

    // Handle incoming messages
    socket.on('message', function (message) {
      try {
        const data = JSON.parse(message);
        console.log(`[VU ${__VU}] Received: ${data.type || data.event || 'unknown'}`);
      } catch (e) {
        console.log(`[VU ${__VU}] Received non-JSON: ${message}`);
      }
    });

    socket.on('error', function (e) {
      console.error(`[VU ${__VU}] WebSocket error: ${e.error()}`);
    });

    socket.on('close', function () {
      console.log(`[VU ${__VU}] WebSocket closed`);
    });

    // Send initial join message based on backend
    if (BACKEND === 'elixir') {
      // Phoenix Channels join
      const joinMessage = JSON.stringify({
        topic: `location:${sessionId}`,
        event: 'phx_join',
        payload: {
          user_id: userId
        },
        ref: `join_${Date.now()}`
      });

      const joinStart = Date.now();
      socket.send(joinMessage);
      wsMessageSendDuration.add(Date.now() - joinStart);
      wsMessageSendRate.add(true);
    }
    // For Rust: No join message needed, authentication via JWT in URL

    // Send location updates immediately
    const updateCount = 3;
    for (let i = 0; i < updateCount; i++) {
      const location = generateLocation();
      let locationMessage;

      if (BACKEND === 'rust') {
        locationMessage = JSON.stringify({
          type: 'location_update',
          data: {
            lat: location.latitude,
            lng: location.longitude,
            accuracy: location.accuracy,
            timestamp: location.timestamp
          }
        });
      } else {
        // Phoenix Channels format
        locationMessage = JSON.stringify({
          topic: `location:${sessionId}`,
          event: 'location_update',
          payload: {
            user_id: userId,
            lat: location.latitude,
            lng: location.longitude,
            accuracy: location.accuracy,
            timestamp: location.timestamp
          },
          ref: `update_${Date.now()}_${i}`
        });
      }

      const sendStart = Date.now();
      socket.send(locationMessage);
      wsMessageSendDuration.add(Date.now() - sendStart);
      wsMessageSendRate.add(true);
      locationUpdatesCounter.add(1);
      
      console.log(`[VU ${__VU}] Sent location update ${i + 1}/${updateCount}`);
      
      // Small delay between messages
      if (i < updateCount - 1) {
        sleep(0.1);
      }
    }

    console.log(`[VU ${__VU}] All updates sent, closing connection`);
    socket.close();
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
}

// Setup function
export function setup() {
  console.log(`Starting ${SCENARIO} WebSocket test against ${BACKEND} backend`);
  console.log(`API URL: ${API_URL}`);
  console.log(`WebSocket URL: ${WS_URL}`);
  console.log(`Target Users: ${scenario.users}`);
  console.log(`Duration: ${scenario.duration}`);

  // Health check
  const healthResponse = http.get(`${API_URL}${CONFIG.backends[BACKEND].health_endpoint}`);
  if (healthResponse.status !== 200) {
    throw new Error(`Backend health check failed: ${healthResponse.status}`);
  }
  
  console.log('Backend health check passed');
  
  return { backend: BACKEND, scenario: SCENARIO };
}

// Teardown function
export function teardown(data) {
  console.log(`WebSocket test completed for ${data.backend} backend`);
  console.log(`Scenario: ${data.scenario}`);
  console.log('Check Prometheus/Grafana for detailed metrics');
}