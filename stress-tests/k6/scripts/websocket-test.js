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
const SCENARIO = __ENV.SCENARIO || 'websocket_connection_storm';
const API_URL = __ENV.API_URL || CONFIG.backends[BACKEND].api_url;
const WS_URL = __ENV.WS_URL || CONFIG.backends[BACKEND].ws_url;

const scenario = CONFIG.scenarios[SCENARIO];

export const options = {
  scenarios: {
    websocket_storm: {
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
  },
};

// Test data generators (same as API test)
function generateSessionName() {
  const prefixes = ['Storm', 'Flood', 'Wave', 'Tsunami', 'Avalanche'];
  const activities = ['Test', 'Load', 'Stress', 'Spike', 'Chaos'];
  const numbers = Math.floor(Math.random() * 10000);
  return `${prefixes[Math.floor(Math.random() * prefixes.length)]} ${activities[Math.floor(Math.random() * activities.length)]} ${numbers}`;
}

function generateUserName() {
  const firstNames = ['Bot', 'Test', 'Load', 'Stress', 'Virtual', 'Sim', 'Auto', 'Mock'];
  const lastNames = ['User', 'Client', 'Tester', 'Agent', 'Worker', 'Instance', 'Unit', 'Process'];
  return `${firstNames[Math.floor(Math.random() * firstNames.length)]} ${lastNames[Math.floor(Math.random() * lastNames.length)]} ${__VU}`;
}

function generateLocation() {
  // Generate random locations around different major cities for variety
  const cities = [
    { lat: 37.7749, lng: -122.4194 }, // San Francisco
    { lat: 40.7128, lng: -74.0060 },  // New York
    { lat: 34.0522, lng: -118.2437 }, // Los Angeles
    { lat: 41.8781, lng: -87.6298 },  // Chicago
    { lat: 29.7604, lng: -95.3698 },  // Houston
  ];
  
  const city = cities[Math.floor(Math.random() * cities.length)];
  const range = 0.05; // roughly 5km radius
  
  return {
    latitude: city.lat + (Math.random() - 0.5) * range,
    longitude: city.lng + (Math.random() - 0.5) * range,
  };
}

function generateAvatarColor() {
  const colors = [
    '#FF5733', '#33FF57', '#3357FF', '#FF33F1', '#F1FF33', '#33FFF1',
    '#FF8C33', '#8C33FF', '#33FF8C', '#FF3333', '#3333FF', '#FFFF33'
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Session setup helper
function createSessionAndJoin() {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Create session
  const sessionPayload = {
    name: generateSessionName(),
    expires_in_minutes: 120, // Longer for stress tests
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
  const sessionId = sessionData.session_id;

  // Join session
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
  console.log(`[VU ${__VU}] Starting WebSocket stress test...`);
  
  // Setup session
  const sessionInfo = createSessionAndJoin();
  if (!sessionInfo) {
    console.error(`[VU ${__VU}] Failed to setup session, aborting`);
    return;
  }

  const { sessionId, userId, wsToken } = sessionInfo;
  console.log(`[VU ${__VU}] Session setup complete: ${sessionId}`);

  // Prepare WebSocket URL with authentication
  let wsUrl;
  if (BACKEND === 'rust') {
    wsUrl = `${WS_URL}/ws?session_id=${sessionId}&user_id=${userId}&token=${wsToken}`;
  } else {
    // Elixir Phoenix Channels
    wsUrl = `${WS_URL}?session_id=${sessionId}&user_id=${userId}&token=${wsToken}`;
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
        console.log(`[VU ${__VU}] Received: ${data.type || 'unknown'}`);
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

    // Send initial presence/join message based on backend
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
      // Phoenix Channels format
      joinMessage = JSON.stringify({
        topic: `session:${sessionId}`,
        event: 'phx_join',
        payload: {
          user_id: userId
        },
        ref: `join_${Date.now()}`
      });
    }

    const joinStart = Date.now();
    socket.send(joinMessage);
    wsMessageSendDuration.add(Date.now() - joinStart);
    wsMessageSendRate.add(true);

    // Location update frequency based on scenario
    const updateFrequency = scenario.location_updates_per_second || 1;
    const updateInterval = 1000 / updateFrequency; // milliseconds

    // Send location updates
    let updateCount = 0;
    const maxUpdates = Math.floor((scenario.duration.replace('m', '') * 60) / (updateInterval / 1000));
    
    const updateTimer = setInterval(() => {
      if (updateCount >= maxUpdates) {
        clearInterval(updateTimer);
        socket.close();
        return;
      }

      const location = generateLocation();
      let locationMessage;

      if (BACKEND === 'rust') {
        locationMessage = JSON.stringify({
          type: 'location_update',
          data: {
            session_id: sessionId,
            user_id: userId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: new Date().toISOString()
          }
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
            timestamp: new Date().toISOString()
          },
          ref: `update_${Date.now()}_${updateCount}`
        });
      }

      const sendStart = Date.now();
      socket.send(locationMessage);
      wsMessageSendDuration.add(Date.now() - sendStart);
      wsMessageSendRate.add(true);
      locationUpdatesCounter.add(1);
      
      updateCount++;
      
      if (updateCount % 100 === 0) {
        console.log(`[VU ${__VU}] Sent ${updateCount} location updates`);
      }
    }, updateInterval);

    // Handle test duration
    setTimeout(() => {
      clearInterval(updateTimer);
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
  console.log(`Starting ${SCENARIO} WebSocket test against ${BACKEND} backend`);
  console.log(`API URL: ${API_URL}`);
  console.log(`WebSocket URL: ${WS_URL}`);
  console.log(`Target Users: ${scenario.users}`);
  console.log(`Duration: ${scenario.duration}`);
  
  if (scenario.location_updates_per_second) {
    console.log(`Location Updates per Second: ${scenario.location_updates_per_second}`);
  }

  // Health check
  const healthResponse = http.get(`${API_URL}${CONFIG.backends[BACKEND].health_endpoint}`);
  if (healthResponse.status !== 200) {
    throw new Error(`Backend health check failed: ${healthResponse.status}`);
  }
  
  console.log('Backend health check passed');
  console.log('WARNING: This test will create many WebSocket connections and generate high load');
  
  return { backend: BACKEND, scenario: SCENARIO };
}

// Teardown function
export function teardown(data) {
  console.log(`WebSocket stress test completed for ${data.backend} backend`);
  console.log(`Scenario: ${data.scenario}`);
  console.log('Check Prometheus/Grafana for detailed metrics');
}