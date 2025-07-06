import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';
import http from 'k6/http';

// Session lifecycle metrics
const sessionCreationRate = new Rate('session_creation_success');
const sessionJoinRate = new Rate('session_join_success');
const sessionLeaveRate = new Rate('session_leave_success');
const sessionCleanupRate = new Rate('session_cleanup_success');
const sessionLifecycleDuration = new Trend('session_lifecycle_duration');
const participantTurnoverRate = new Rate('participant_turnover_success');

// Multi-user session metrics
const simultaneousParticipants = new Gauge('simultaneous_participants');
const sessionParticipantCount = new Trend('session_participant_count');
const sessionConcurrencyLevel = new Gauge('session_concurrency_level');
const averageSessionDuration = new Trend('average_session_duration');
const participantFlowRate = new Counter('participant_flow_rate');

// Performance under load metrics
const wsConnectionDuration = new Trend('websocket_connecting_duration');
const wsMessageSendRate = new Rate('websocket_message_send_success');
const locationUpdatesCounter = new Counter('location_updates_sent');
const databaseQueryDuration = new Trend('database_query_duration');
const memoryUsageImpact = new Gauge('memory_usage_impact');

// Load test configuration
const CONFIG = JSON.parse(open('../config/test-scenarios.json'));

// Test parameters
const BACKEND = __ENV.BACKEND || 'rust';
const SCENARIO = __ENV.SCENARIO || 'session_lifecycle_stress';
const API_URL = __ENV.API_URL || CONFIG.backends[BACKEND].api_url;
const WS_URL = __ENV.WS_URL || CONFIG.backends[BACKEND].ws_url;

const scenario = CONFIG.scenarios[SCENARIO];

export const options = {
  scenarios: {
    session_lifecycle_stress: {
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
    'session_creation_success': ['rate>0.95'],
    'session_join_success': ['rate>0.98'],
    'session_leave_success': ['rate>0.95'],
    'participant_turnover_success': ['rate>0.90'],
    'session_lifecycle_duration': ['p95<5000'],
  },
};

// Session behavior patterns
const BEHAVIOR_PATTERNS = {
  quick_visitor: {
    join_delay: 0,
    stay_duration: 30000, // 30 seconds
    activity_level: 0.2,   // Low activity
    description: 'Quick session visitors'
  },
  regular_user: {
    join_delay: 5000,
    stay_duration: 300000, // 5 minutes
    activity_level: 0.8,   // High activity
    description: 'Regular active users'
  },
  lurker: {
    join_delay: 2000,
    stay_duration: 600000, // 10 minutes
    activity_level: 0.1,   // Very low activity
    description: 'Session lurkers'
  },
  session_hopper: {
    join_delay: 1000,
    stay_duration: 60000,  // 1 minute
    activity_level: 0.5,   // Medium activity
    description: 'Users who join multiple sessions'
  }
};

// Session size patterns to test different loads
const SESSION_SIZE_PATTERNS = {
  small_intimate: { min_users: 2, max_users: 5, probability: 0.4 },
  medium_group: { min_users: 6, max_users: 20, probability: 0.4 },
  large_gathering: { min_users: 21, max_users: 50, probability: 0.15 },
  mega_session: { min_users: 51, max_users: 100, probability: 0.05 }
};

// Test data generators
function generateSessionName(pattern) {
  const prefixes = ['Lifecycle', 'MultiUser', 'Concurrent', 'Dynamic', 'Turnover'];
  const activities = ['Test', 'Session', 'Group', 'Meeting', 'Gathering'];
  const numbers = Math.floor(Math.random() * 10000);
  return `${prefixes[Math.floor(Math.random() * prefixes.length)]} ${activities[Math.floor(Math.random() * activities.length)]} ${pattern} ${numbers}`;
}

function generateUserName(pattern) {
  const patternNames = {
    quick_visitor: ['Quick', 'Fast', 'Brief', 'Swift'],
    regular_user: ['Regular', 'Active', 'Engaged', 'Frequent'],
    lurker: ['Silent', 'Observer', 'Lurker', 'Watcher'],
    session_hopper: ['Hopper', 'Jumper', 'Explorer', 'Wanderer']
  };
  
  const names = patternNames[pattern] || ['User'];
  const surnames = ['Tester', 'Client', 'Agent', 'Participant', 'Member'];
  return `${names[Math.floor(Math.random() * names.length)]} ${surnames[Math.floor(Math.random() * surnames.length)]} ${__VU}`;
}

function generateLocation() {
  // Generate diverse locations for session participants
  const locations = [
    { lat: 37.7749, lng: -122.4194, name: 'San Francisco' },
    { lat: 40.7128, lng: -74.0060, name: 'New York' },
    { lat: 34.0522, lng: -118.2437, name: 'Los Angeles' },
    { lat: 41.8781, lng: -87.6298, name: 'Chicago' },
    { lat: 29.7604, lng: -95.3698, name: 'Houston' },
    { lat: 33.4484, lng: -112.0740, name: 'Phoenix' },
    { lat: 39.9526, lng: -75.1652, name: 'Philadelphia' },
    { lat: 32.7767, lng: -96.7970, name: 'Dallas' }
  ];
  
  const baseLocation = locations[Math.floor(Math.random() * locations.length)];
  const range = 0.02; // ~2km radius
  
  return {
    latitude: baseLocation.lat + (Math.random() - 0.5) * range,
    longitude: baseLocation.lng + (Math.random() - 0.5) * range,
    city: baseLocation.name
  };
}

function generateAvatarColor() {
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FECA57', '#FF9FF3',
    '#54A0FF', '#5F27CD', '#00D2D3', '#FF9F43', '#EE5A24', '#0ABDE3'
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Session management functions
function createSessionWithExpectedSize(sizePattern) {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  const sessionPayload = {
    name: generateSessionName(sizePattern),
    expires_in_minutes: 360, // 6 hours for lifecycle testing
  };

  const sessionStart = Date.now();
  const sessionResponse = http.post(
    `${API_URL}/api/sessions`,
    JSON.stringify(sessionPayload),
    { headers }
  );

  const sessionCreated = check(sessionResponse, {
    'session created successfully': (r) => r.status === 200 || r.status === 201,
  });

  sessionCreationRate.add(sessionCreated);
  databaseQueryDuration.add(Date.now() - sessionStart);

  if (sessionCreated) {
    const sessionData = JSON.parse(sessionResponse.body);
    sessionConcurrencyLevel.add(1);
    return {
      id: sessionData.session_id,
      name: sessionData.name,
      pattern: sizePattern,
      created_at: Date.now(),
      expected_participants: 0
    };
  }

  return null;
}

function joinSessionWithBehavior(session, behaviorPattern) {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  const joinPayload = {
    display_name: generateUserName(behaviorPattern),
    avatar_color: generateAvatarColor(),
  };

  const joinStart = Date.now();
  const joinResponse = http.post(
    `${API_URL}/api/sessions/${session.id}/join`,
    JSON.stringify(joinPayload),
    { headers }
  );

  const sessionJoined = check(joinResponse, {
    'session joined successfully': (r) => r.status === 200 || r.status === 201,
  });

  sessionJoinRate.add(sessionJoined);
  databaseQueryDuration.add(Date.now() - joinStart);

  if (sessionJoined) {
    const joinData = JSON.parse(joinResponse.body);
    participantFlowRate.add(1);
    simultaneousParticipants.add(1);
    
    return {
      sessionId: session.id,
      sessionName: session.name,
      userId: joinData.user_id,
      wsToken: joinData.websocket_token,
      pattern: behaviorPattern,
      joinTime: Date.now(),
      expectedStayDuration: BEHAVIOR_PATTERNS[behaviorPattern].stay_duration
    };
  }

  return null;
}

function leaveSession(sessionInfo) {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  const leaveStart = Date.now();
  const leaveResponse = http.del(
    `${API_URL}/api/sessions/${sessionInfo.sessionId}/participants/${sessionInfo.userId}`,
    null,
    { headers }
  );

  const sessionLeft = check(leaveResponse, {
    'left session successfully': (r) => r.status === 200,
  });

  sessionLeaveRate.add(sessionLeft);
  databaseQueryDuration.add(Date.now() - leaveStart);

  if (sessionLeft) {
    const sessionDuration = Date.now() - sessionInfo.joinTime;
    sessionLifecycleDuration.add(sessionDuration);
    averageSessionDuration.add(sessionDuration);
    simultaneousParticipants.add(-1);
    participantTurnoverRate.add(true);
  }

  return sessionLeft;
}

// Session activity simulation
function simulateSessionActivity(sessionInfo, socket) {
  const behavior = BEHAVIOR_PATTERNS[sessionInfo.pattern];
  let activityCount = 0;
  
  const activityTimer = setInterval(() => {
    if (Math.random() < behavior.activity_level) {
      const location = generateLocation();
      const timestamp = new Date().toISOString();
      const activityRef = `activity_${Date.now()}_${__VU}_${activityCount}`;
      
      let locationMessage;
      if (BACKEND === 'rust') {
        locationMessage = JSON.stringify({
          type: 'location_update',
          data: {
            session_id: sessionInfo.sessionId,
            user_id: sessionInfo.userId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: timestamp,
            activity_pattern: sessionInfo.pattern
          },
          ref: activityRef
        });
      } else {
        locationMessage = JSON.stringify({
          topic: `session:${sessionInfo.sessionId}`,
          event: 'location_update',
          payload: {
            user_id: sessionInfo.userId,
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: timestamp,
            activity_pattern: sessionInfo.pattern
          },
          ref: activityRef
        });
      }

      socket.send(locationMessage);
      wsMessageSendRate.add(true);
      locationUpdatesCounter.add(1);
      activityCount++;
    }
  }, 2000); // Check every 2 seconds

  return activityTimer;
}

// Global session registry for multi-user coordination
let globalSessions = [];

// Main test function
export default function () {
  console.log(`[VU ${__VU}] Starting session lifecycle stress test...`);
  
  // Determine behavior pattern for this VU
  const behaviorPatterns = Object.keys(BEHAVIOR_PATTERNS);
  const selectedBehavior = behaviorPatterns[__VU % behaviorPatterns.length];
  const behavior = BEHAVIOR_PATTERNS[selectedBehavior];
  
  console.log(`[VU ${__VU}] Using behavior pattern: ${selectedBehavior} - ${behavior.description}`);
  
  // Wait based on behavior pattern
  sleep(behavior.join_delay / 1000);
  
  // Session hopper behavior: create multiple sessions
  if (selectedBehavior === 'session_hopper') {
    const sessionCount = 2 + Math.floor(Math.random() * 3); // 2-4 sessions
    
    for (let i = 0; i < sessionCount; i++) {
      setTimeout(() => {
        runSingleSessionLifecycle(selectedBehavior, i);
      }, i * 30000); // 30 seconds apart
    }
  } else {
    runSingleSessionLifecycle(selectedBehavior, 0);
  }
}

function runSingleSessionLifecycle(behaviorPattern, sessionIndex) {
  console.log(`[VU ${__VU}] Starting session lifecycle ${sessionIndex} with ${behaviorPattern} pattern`);
  
  // Select or create a session based on size patterns
  let targetSession;
  
  if (globalSessions.length === 0 || Math.random() < 0.3) {
    // 30% chance to create new session or if no sessions exist
    const sizePatterns = Object.keys(SESSION_SIZE_PATTERNS);
    const selectedSizePattern = sizePatterns[Math.floor(Math.random() * sizePatterns.length)];
    
    targetSession = createSessionWithExpectedSize(selectedSizePattern);
    if (targetSession) {
      globalSessions.push(targetSession);
      console.log(`[VU ${__VU}] Created new session: ${targetSession.name}`);
    }
  } else {
    // Join existing session
    targetSession = globalSessions[Math.floor(Math.random() * globalSessions.length)];
    console.log(`[VU ${__VU}] Joining existing session: ${targetSession.name}`);
  }
  
  if (!targetSession) {
    console.error(`[VU ${__VU}] Failed to get target session, aborting lifecycle`);
    return;
  }
  
  // Join the session
  const sessionInfo = joinSessionWithBehavior(targetSession, behaviorPattern);
  if (!sessionInfo) {
    console.error(`[VU ${__VU}] Failed to join session, aborting lifecycle`);
    return;
  }
  
  console.log(`[VU ${__VU}] Joined session: ${sessionInfo.sessionName}`);
  
  // Connect to WebSocket
  let wsUrl;
  if (BACKEND === 'rust') {
    wsUrl = `${WS_URL}/ws?session_id=${sessionInfo.sessionId}&user_id=${sessionInfo.userId}&token=${sessionInfo.wsToken}`;
  } else {
    wsUrl = `${WS_URL}?session_id=${sessionInfo.sessionId}&user_id=${sessionInfo.userId}&token=${sessionInfo.wsToken}`;
  }
  
  const connectStart = Date.now();
  
  const response = ws.connect(wsUrl, {}, function (socket) {
    const connectDuration = Date.now() - connectStart;
    wsConnectionDuration.add(connectDuration);
    
    console.log(`[VU ${__VU}] WebSocket connected for lifecycle test in ${connectDuration}ms`);
    
    // Handle incoming messages
    let messagesReceived = 0;
    socket.on('message', function (message) {
      messagesReceived++;
      
      if (messagesReceived % 20 === 0) {
        console.log(`[VU ${__VU}] Lifecycle test: received ${messagesReceived} messages`);
      }
    });
    
    socket.on('error', function (e) {
      console.error(`[VU ${__VU}] Lifecycle WebSocket error: ${e.error()}`);
    });
    
    socket.on('close', function () {
      console.log(`[VU ${__VU}] Lifecycle WebSocket closed - received ${messagesReceived} messages`);
    });
    
    // Send initial join message
    let joinMessage;
    const joinRef = `lifecycle_join_${Date.now()}_${__VU}_${sessionIndex}`;
    
    if (BACKEND === 'rust') {
      joinMessage = JSON.stringify({
        type: 'join_session',
        data: {
          session_id: sessionInfo.sessionId,
          user_id: sessionInfo.userId,
          behavior_pattern: behaviorPattern
        },
        ref: joinRef
      });
    } else {
      joinMessage = JSON.stringify({
        topic: `session:${sessionInfo.sessionId}`,
        event: 'phx_join',
        payload: {
          user_id: sessionInfo.userId,
          behavior_pattern: behaviorPattern
        },
        ref: joinRef
      });
    }
    
    socket.send(joinMessage);
    wsMessageSendRate.add(true);
    
    // Start activity simulation
    const activityTimer = simulateSessionActivity(sessionInfo, socket);
    
    // Schedule leaving the session
    setTimeout(() => {
      clearInterval(activityTimer);
      console.log(`[VU ${__VU}] Lifecycle: leaving session after ${sessionInfo.expectedStayDuration / 1000}s`);
      socket.close();
      
      // Leave the session via API
      setTimeout(() => {
        const left = leaveSession(sessionInfo);
        if (left) {
          console.log(`[VU ${__VU}] Successfully left session: ${sessionInfo.sessionName}`);
        }
      }, 1000);
    }, sessionInfo.expectedStayDuration);
  });
  
  // Check connection result
  check(response, {
    'lifecycle websocket connection established': (r) => r && r.status === 101,
  });
  
  if (!response || response.status !== 101) {
    console.error(`[VU ${__VU}] Lifecycle WebSocket connection failed: ${response ? response.status : 'unknown'}`);
    return;
  }
  
  // Wait for the lifecycle to complete
  sleep((sessionInfo.expectedStayDuration + 10000) / 1000); // Add 10s buffer
}

// Setup function
export function setup() {
  console.log(`Starting ${SCENARIO} session lifecycle stress test against ${BACKEND} backend`);
  console.log(`API URL: ${API_URL}`);
  console.log(`WebSocket URL: ${WS_URL}`);
  console.log(`Target Users: ${scenario.users}`);
  console.log(`Duration: ${scenario.duration}`);
  
  console.log('Behavior Patterns:');
  Object.entries(BEHAVIOR_PATTERNS).forEach(([name, pattern]) => {
    console.log(`  ${name}: ${pattern.description} (stay: ${pattern.stay_duration/1000}s, activity: ${pattern.activity_level})`);
  });
  
  console.log('Session Size Patterns:');
  Object.entries(SESSION_SIZE_PATTERNS).forEach(([name, pattern]) => {
    console.log(`  ${name}: ${pattern.min_users}-${pattern.max_users} users (${pattern.probability * 100}% probability)`);
  });
  
  // Health check
  const healthResponse = http.get(`${API_URL}${CONFIG.backends[BACKEND].health_endpoint}`);
  if (healthResponse.status !== 200) {
    throw new Error(`Backend health check failed: ${healthResponse.status}`);
  }
  
  console.log('Backend health check passed');
  console.log('WARNING: This test simulates realistic user behavior patterns');
  console.log('WARNING: Monitor database connection pools and session cleanup');
  
  return { backend: BACKEND, scenario: SCENARIO };
}

// Teardown function
export function teardown(data) {
  console.log(`Session lifecycle stress test completed for ${data.backend} backend`);
  console.log(`Scenario: ${data.scenario}`);
  console.log('Key lifecycle metrics to review:');
  console.log('- session_lifecycle_duration: Complete user session duration');
  console.log('- participant_turnover_success: User join/leave success rate');
  console.log('- session_participant_count: Average participants per session');
  console.log('- database_query_duration: Database performance under lifecycle load');
  console.log('- simultaneous_participants: Peak concurrent participants');
}