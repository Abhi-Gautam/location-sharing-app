import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const sessionCreationRate = new Rate('session_creation_success');
const sessionJoinRate = new Rate('session_join_success');
const locationUpdateRate = new Rate('location_update_success');
const sessionCreationDuration = new Trend('session_creation_duration');

// Load test configuration
const CONFIG = JSON.parse(open('../config/test-scenarios.json'));

// Test parameters (can be overridden by environment variables)
const BACKEND = __ENV.BACKEND || 'rust';
const SCENARIO = __ENV.SCENARIO || 'load_test';
const API_URL = __ENV.API_URL || CONFIG.backends[BACKEND].api_url;
const WS_URL = __ENV.WS_URL || CONFIG.backends[BACKEND].ws_url;

const scenario = CONFIG.scenarios[SCENARIO];

export const options = {
  scenarios: {
    api_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: scenario.rampUp, target: scenario.users },
        { duration: scenario.duration, target: scenario.users },
        { duration: '1m', target: 0 },
      ],
    },
  },
  thresholds: CONFIG.thresholds,
};

// Test data generators
function generateSessionName() {
  const prefixes = ['Team', 'Squad', 'Group', 'Crew', 'Gang'];
  const activities = ['Adventure', 'Meeting', 'Journey', 'Trip', 'Mission'];
  const numbers = Math.floor(Math.random() * 1000);
  return `${prefixes[Math.floor(Math.random() * prefixes.length)]} ${activities[Math.floor(Math.random() * activities.length)]} ${numbers}`;
}

function generateUserName() {
  const firstNames = ['Alex', 'Sam', 'Jamie', 'Taylor', 'Morgan', 'Casey', 'Jordan', 'Riley'];
  const lastNames = ['Smith', 'Johnson', 'Brown', 'Davis', 'Wilson', 'Moore', 'Taylor', 'Anderson'];
  return `${firstNames[Math.floor(Math.random() * firstNames.length)]} ${lastNames[Math.floor(Math.random() * lastNames.length)]}`;
}

function generateLocation() {
  // Generate random location around San Francisco Bay Area
  const baseLat = 37.7749;
  const baseLng = -122.4194;
  const range = 0.1; // roughly 10km radius
  
  return {
    latitude: baseLat + (Math.random() - 0.5) * range,
    longitude: baseLng + (Math.random() - 0.5) * range,
  };
}

function generateAvatarColor() {
  const colors = ['#FF5733', '#33FF57', '#3357FF', '#FF33F1', '#F1FF33', '#33FFF1'];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Main test function
export default function () {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Step 1: Create a session
  console.log(`[VU ${__VU}] Creating session...`);
  const sessionPayload = {
    name: generateSessionName(),
    expires_in_minutes: 60,
  };

  const sessionStart = Date.now();
  const sessionResponse = http.post(
    `${API_URL}/api/sessions`,
    JSON.stringify(sessionPayload),
    { headers }
  );

  const sessionCreated = check(sessionResponse, {
    'session created successfully': (r) => r.status === 200 || r.status === 201,
    'session response has session_id': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.session_id !== undefined;
      } catch (e) {
        return false;
      }
    },
  });

  sessionCreationRate.add(sessionCreated);
  sessionCreationDuration.add(Date.now() - sessionStart);

  if (!sessionCreated) {
    console.error(`[VU ${__VU}] Failed to create session: ${sessionResponse.status} ${sessionResponse.body}`);
    return;
  }

  const sessionData = JSON.parse(sessionResponse.body);
  const sessionId = sessionData.session_id;
  console.log(`[VU ${__VU}] Created session: ${sessionId}`);

  sleep(Math.random() * 2); // Random delay 0-2 seconds

  // Step 2: Join the session
  console.log(`[VU ${__VU}] Joining session...`);
  const joinPayload = {
    display_name: generateUserName(),
    avatar_color: generateAvatarColor(),
  };

  const joinResponse = http.post(
    `${API_URL}/api/sessions/${sessionId}/join`,
    JSON.stringify(joinPayload),
    { headers }
  );

  const sessionJoined = check(joinResponse, {
    'session joined successfully': (r) => r.status === 200 || r.status === 201,
    'join response has user_id': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.user_id !== undefined;
      } catch (e) {
        return false;
      }
    },
    'join response has websocket_token': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.websocket_token !== undefined;
      } catch (e) {
        return false;
      }
    },
  });

  sessionJoinRate.add(sessionJoined);

  if (!sessionJoined) {
    console.error(`[VU ${__VU}] Failed to join session: ${joinResponse.status} ${joinResponse.body}`);
    return;
  }

  const joinData = JSON.parse(joinResponse.body);
  const userId = joinData.user_id;
  const wsToken = joinData.websocket_token;

  sleep(Math.random() * 2);

  // Step 3: Get session details
  console.log(`[VU ${__VU}] Getting session details...`);
  const detailsResponse = http.get(`${API_URL}/api/sessions/${sessionId}`, { headers });
  
  check(detailsResponse, {
    'session details retrieved': (r) => r.status === 200,
    'session details have participant count': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.participant_count !== undefined;
      } catch (e) {
        return false;
      }
    },
  });

  sleep(Math.random() * 2);

  // Step 4: Get participants list
  console.log(`[VU ${__VU}] Getting participants list...`);
  const participantsResponse = http.get(`${API_URL}/api/sessions/${sessionId}/participants`, { headers });
  
  check(participantsResponse, {
    'participants list retrieved': (r) => r.status === 200,
    'participants list is array': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body.participants);
      } catch (e) {
        return false;
      }
    },
  });

  sleep(Math.random() * 3);

  // Step 5: Leave session (cleanup)
  console.log(`[VU ${__VU}] Leaving session...`);
  const leaveResponse = http.del(`${API_URL}/api/sessions/${sessionId}/participants/${userId}`, null, { headers });
  
  check(leaveResponse, {
    'left session successfully': (r) => r.status === 200,
  });

  console.log(`[VU ${__VU}] Test iteration completed`);
}

// Setup function
export function setup() {
  console.log(`Starting ${SCENARIO} test against ${BACKEND} backend`);
  console.log(`API URL: ${API_URL}`);
  console.log(`WebSocket URL: ${WS_URL}`);
  
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
  console.log(`Test completed for ${data.backend} backend with ${data.scenario} scenario`);
}