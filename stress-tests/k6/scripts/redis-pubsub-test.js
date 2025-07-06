import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';
import http from 'k6/http';

// Redis-specific metrics
const redisPublishRate = new Rate('redis_publish_success');
const redisSubscribeRate = new Rate('redis_subscribe_success');
const redisChannelLatency = new Trend('redis_channel_latency');
const redisMessageThroughput = new Counter('redis_messages_per_second');
const activeChannelsGauge = new Gauge('active_redis_channels');
const channelSubscribersGauge = new Gauge('channel_subscribers_count');
const messageDeliveryLatency = new Trend('message_delivery_latency');
const messageBroadcastFanout = new Counter('message_broadcast_fanout');

// Connection metrics
const wsConnectionRate = new Rate('websocket_connection_success');
const wsMessageSendRate = new Rate('websocket_message_send_success');
const locationUpdatesCounter = new Counter('location_updates_sent');
const participantJoinCounter = new Counter('participant_joins');

// Load test configuration
const CONFIG = JSON.parse(open('../config/test-scenarios.json'));

// Test parameters
const BACKEND = __ENV.BACKEND || 'rust';
const SCENARIO = __ENV.SCENARIO || 'redis_stress_test';
const API_URL = __ENV.API_URL || CONFIG.backends[BACKEND].api_url;
const WS_URL = __ENV.WS_URL || CONFIG.backends[BACKEND].ws_url;

const scenario = CONFIG.scenarios[SCENARIO];

export const options = {
  scenarios: {
    redis_pubsub_stress: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: scenario.rampUp, target: scenario.users },
        { duration: scenario.duration, target: scenario.users },
        { duration: '3m', target: 0 },
      ],
    },
  },
  thresholds: {
    ...CONFIG.thresholds,
    'redis_publish_success': ['rate>0.99'],
    'redis_subscribe_success': ['rate>0.99'],
    'redis_channel_latency': ['p95<100', 'p99<200'],
    'message_delivery_latency': ['p95<300', 'p99<500'],
  },
};

// Redis channel patterns for different session distributions
const CHANNEL_PATTERNS = {
  // High density: many users in few sessions (Redis channel stress)
  high_density: {
    session_count: 10,
    users_per_session: 100,
    description: 'Many users per Redis channel'
  },
  // Wide distribution: few users in many sessions (Redis channel scaling)
  wide_distribution: {
    session_count: 500,
    users_per_session: 2,
    description: 'Many Redis channels with few users each'
  },
  // Mixed pattern: realistic distribution
  mixed_pattern: {
    session_count: 50,
    users_per_session: 20,
    description: 'Balanced Redis channel distribution'
  }
};

// Message burst patterns to stress Redis
const BURST_PATTERNS = {
  steady: { interval: 1000, variance: 100 },
  bursty: { interval: 500, variance: 400 },
  spike: { interval: 100, variance: 50 },
};

// Test data generators
function generateSessionName() {
  const prefixes = ['RedisStorm', 'PubSubFlood', 'ChannelWave', 'BroadcastTest', 'RedisStress'];
  const activities = ['High', 'Wide', 'Mixed', 'Burst', 'Spike'];
  const numbers = Math.floor(Math.random() * 10000);
  return `${prefixes[Math.floor(Math.random() * prefixes.length)]} ${activities[Math.floor(Math.random() * activities.length)]} ${numbers}`;
}

function generateUserName() {
  const firstNames = ['Redis', 'PubSub', 'Channel', 'Subscriber', 'Publisher', 'Broadcast', 'Stream', 'Pipeline'];
  const lastNames = ['Client', 'Tester', 'Agent', 'Worker', 'Node', 'Instance', 'Unit', 'Process'];
  return `${firstNames[Math.floor(Math.random() * firstNames.length)]} ${lastNames[Math.floor(Math.random() * lastNames.length)]} ${__VU}`;
}

function generateLocation() {
  // Generate clustered locations to test geospatial Redis operations
  const clusters = [
    { lat: 37.7749, lng: -122.4194, radius: 0.01 }, // SF Downtown
    { lat: 37.8044, lng: -122.2712, radius: 0.01 }, // Oakland
    { lat: 37.6879, lng: -122.4702, radius: 0.01 }, // Daly City
    { lat: 37.4419, lng: -122.1430, radius: 0.01 }, // Palo Alto
  ];
  
  const cluster = clusters[Math.floor(Math.random() * clusters.length)];
  
  return {
    latitude: cluster.lat + (Math.random() - 0.5) * cluster.radius,
    longitude: cluster.lng + (Math.random() - 0.5) * cluster.radius,
  };
}

function generateAvatarColor() {
  const colors = [
    '#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#FF00FF', '#00FFFF',
    '#FF8000', '#8000FF', '#00FF80', '#FF0080', '#80FF00', '#0080FF'
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Session management with Redis channel optimization
function createSessionsForPattern(pattern) {
  const sessions = [];
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  const channelPattern = CHANNEL_PATTERNS[pattern];
  console.log(`[VU ${__VU}] Creating sessions for ${channelPattern.description}`);

  for (let i = 0; i < channelPattern.session_count; i++) {
    const sessionPayload = {
      name: `${generateSessionName()} - ${pattern} - ${i}`,
      expires_in_minutes: 240, // Extended for Redis stress testing
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
        targetUsers: channelPattern.users_per_session,
        pattern: pattern,
      });
    }
  }

  activeChannelsGauge.add(sessions.length);
  return sessions;
}

function selectSessionByLoadBalancing(sessions, currentConnections) {
  // Select session based on Redis channel load balancing
  // Prefer sessions with fewer current connections for balanced testing
  sessions.sort((a, b) => {
    const aConnections = currentConnections[a.id] || 0;
    const bConnections = currentConnections[b.id] || 0;
    return aConnections - bConnections;
  });
  
  return sessions[0];
}

function joinSessionForRedisTest(session) {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  const joinPayload = {
    display_name: generateUserName(),
    avatar_color: generateAvatarColor(),
  };

  const joinResponse = http.post(
    `${API_URL}/api/sessions/${session.id}/join`,
    JSON.stringify(joinPayload),
    { headers }
  );

  if (joinResponse.status === 200 || joinResponse.status === 201) {
    const joinData = JSON.parse(joinResponse.body);
    return {
      sessionId: session.id,
      sessionName: session.name,
      pattern: session.pattern,
      userId: joinData.user_id,
      wsToken: joinData.websocket_token,
    };
  }

  return null;
}

// Redis-focused location update with timing
function createRedisOptimizedLocationUpdater(sessionInfo, socket) {
  const pattern = BURST_PATTERNS[sessionInfo.pattern] || BURST_PATTERNS.steady;
  let updateCount = 0;
  const messageTimestamps = new Map();
  
  return function sendLocationUpdate() {
    const location = generateLocation();
    const timestamp = new Date().toISOString();
    const updateRef = `redis_update_${Date.now()}_${__VU}_${updateCount}`;
    
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
          redis_test_marker: true,
          update_sequence: updateCount
        },
        ref: updateRef
      });
    } else {
      // Phoenix Channels format
      locationMessage = JSON.stringify({
        topic: `session:${sessionInfo.sessionId}`,
        event: 'location_update',
        payload: {
          user_id: sessionInfo.userId,
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: timestamp,
          redis_test_marker: true,
          update_sequence: updateCount
        },
        ref: updateRef
      });
    }

    const sendStart = Date.now();
    messageTimestamps.set(updateRef, sendStart);
    
    socket.send(locationMessage);
    wsMessageSendRate.add(true);
    locationUpdatesCounter.add(1);
    redisMessageThroughput.add(1);
    
    updateCount++;
    
    if (updateCount % 25 === 0) {
      console.log(`[VU ${__VU}] Redis test: sent ${updateCount} updates to session ${sessionInfo.sessionId}`);
    }
    
    // Calculate next interval with variance
    const baseInterval = pattern.interval;
    const variance = pattern.variance;
    const nextInterval = baseInterval + (Math.random() - 0.5) * variance;
    
    return { nextInterval, messageTimestamps };
  };
}

// Main test function
export default function () {
  console.log(`[VU ${__VU}] Starting Redis pub/sub stress test...`);
  
  // Determine which Redis pattern to test based on VU distribution
  const vuPattern = __VU % 3;
  const patterns = ['high_density', 'wide_distribution', 'mixed_pattern'];
  const selectedPattern = patterns[vuPattern];
  
  console.log(`[VU ${__VU}] Using Redis pattern: ${selectedPattern}`);
  
  // Create sessions based on pattern
  const sessions = createSessionsForPattern(selectedPattern);
  
  if (sessions.length === 0) {
    console.error(`[VU ${__VU}] Failed to create any sessions for Redis testing, aborting`);
    return;
  }

  console.log(`[VU ${__VU}] Created ${sessions.length} sessions for Redis ${selectedPattern} pattern`);

  // Track connections per session for load balancing
  const connectionTracker = {};
  
  // Join a session using Redis-optimized selection
  const selectedSession = selectSessionByLoadBalancing(sessions, connectionTracker);
  const sessionInfo = joinSessionForRedisTest(selectedSession);
  
  if (!sessionInfo) {
    console.error(`[VU ${__VU}] Failed to join session for Redis testing, aborting`);
    return;
  }

  connectionTracker[sessionInfo.sessionId] = (connectionTracker[sessionInfo.sessionId] || 0) + 1;
  channelSubscribersGauge.add(1);

  console.log(`[VU ${__VU}] Joined Redis session: ${sessionInfo.sessionName} (${sessionInfo.pattern})`);

  // Prepare WebSocket URL
  let wsUrl;
  if (BACKEND === 'rust') {
    wsUrl = `${WS_URL}/ws?session_id=${sessionInfo.sessionId}&user_id=${sessionInfo.userId}&token=${sessionInfo.wsToken}`;
  } else {
    wsUrl = `${WS_URL}?session_id=${sessionInfo.sessionId}&user_id=${sessionInfo.userId}&token=${sessionInfo.wsToken}`;
  }

  console.log(`[VU ${__VU}] Connecting to WebSocket for Redis testing: ${wsUrl}`);

  // WebSocket connection with Redis-specific monitoring
  const connectStart = Date.now();
  
  const response = ws.connect(wsUrl, {}, function (socket) {
    const connectDuration = Date.now() - connectStart;
    
    console.log(`[VU ${__VU}] Redis WebSocket connected in ${connectDuration}ms`);
    wsConnectionRate.add(true);
    participantJoinCounter.add(1);
    redisSubscribeRate.add(true);

    // Track Redis message delivery performance
    const redisMessageTracker = new Map();
    let messagesReceived = 0;
    let messagesSent = 0;

    // Enhanced message handling for Redis performance tracking
    socket.on('message', function (message) {
      const receiveTime = Date.now();
      messagesReceived++;
      
      try {
        const data = JSON.parse(message);
        
        // Track Redis pub/sub latency for location updates
        if (data.type === 'location_update' && data.data && data.data.redis_test_marker) {
          const messageTime = new Date(data.data.timestamp).getTime();
          const redisLatency = receiveTime - messageTime;
          
          if (redisLatency > 0 && redisLatency < 30000) { // Sanity check
            redisChannelLatency.add(redisLatency);
            messageDeliveryLatency.add(redisLatency);
          }
          
          // Track message fanout (how many users received this update)
          if (data.data.user_id !== sessionInfo.userId) {
            messageBroadcastFanout.add(1);
          }
        }
        
        // Track response latency for our own messages
        if (data.ref && redisMessageTracker.has(data.ref)) {
          const sendTime = redisMessageTracker.get(data.ref);
          const roundTripLatency = receiveTime - sendTime;
          messageDeliveryLatency.add(roundTripLatency);
          redisMessageTracker.delete(data.ref);
        }
        
        if (messagesReceived % 50 === 0) {
          console.log(`[VU ${__VU}] Redis test: received ${messagesReceived} messages`);
        }
      } catch (e) {
        console.log(`[VU ${__VU}] Redis test: received non-JSON message`);
      }
    });

    socket.on('error', function (e) {
      console.error(`[VU ${__VU}] Redis WebSocket error: ${e.error()}`);
    });

    socket.on('close', function () {
      console.log(`[VU ${__VU}] Redis WebSocket closed - sent: ${messagesSent}, received: ${messagesReceived}`);
    });

    // Send initial join message
    let joinMessage;
    const joinRef = `redis_join_${Date.now()}_${__VU}`;
    
    if (BACKEND === 'rust') {
      joinMessage = JSON.stringify({
        type: 'join_session',
        data: {
          session_id: sessionInfo.sessionId,
          user_id: sessionInfo.userId,
          redis_test_mode: true
        },
        ref: joinRef
      });
    } else {
      joinMessage = JSON.stringify({
        topic: `session:${sessionInfo.sessionId}`,
        event: 'phx_join',
        payload: {
          user_id: sessionInfo.userId,
          redis_test_mode: true
        },
        ref: joinRef
      });
    }

    const joinStart = Date.now();
    redisMessageTracker.set(joinRef, joinStart);
    socket.send(joinMessage);
    wsMessageSendRate.add(true);
    redisPublishRate.add(true);
    messagesSent++;

    // Create Redis-optimized location updater
    const locationUpdater = createRedisOptimizedLocationUpdater(sessionInfo, socket);

    // Start location updates with Redis-focused timing
    const updateTimer = setInterval(() => {
      const result = locationUpdater();
      
      // Merge timing maps
      result.messageTimestamps.forEach((timestamp, ref) => {
        redisMessageTracker.set(ref, timestamp);
      });
      
      messagesSent++;
    }, 1000); // Base interval, actual interval varies by pattern

    // Simulate Redis channel stress patterns
    const stressTimer = setInterval(() => {
      // Simulate burst sends to stress Redis pub/sub
      if (Math.random() < 0.2) { // 20% chance every interval
        for (let i = 0; i < 5; i++) {
          setTimeout(() => {
            const result = locationUpdater();
            result.messageTimestamps.forEach((timestamp, ref) => {
              redisMessageTracker.set(ref, timestamp);
            });
            messagesSent++;
          }, i * 50); // 50ms apart
        }
        console.log(`[VU ${__VU}] Redis stress: sent burst of 5 messages`);
      }
    }, 10000); // Every 10 seconds

    // Handle test duration
    setTimeout(() => {
      clearInterval(updateTimer);
      clearInterval(stressTimer);
      console.log(`[VU ${__VU}] Redis test duration reached, closing connection`);
      console.log(`[VU ${__VU}] Final stats - sent: ${messagesSent}, received: ${messagesReceived}`);
      socket.close();
    }, (parseInt(scenario.duration.replace('m', '')) * 60 + 30) * 1000);
  });

  // Check connection result
  check(response, {
    'redis websocket connection established': (r) => r && r.status === 101,
  });

  if (!response || response.status !== 101) {
    console.error(`[VU ${__VU}] Redis WebSocket connection failed: ${response ? response.status : 'unknown'}`);
    wsConnectionRate.add(false);
    redisSubscribeRate.add(false);
    return;
  }

  // Keep the test running
  sleep(parseInt(scenario.duration.replace('m', '')) * 60 + 60);
}

// Setup function
export function setup() {
  console.log(`Starting ${SCENARIO} Redis pub/sub stress test against ${BACKEND} backend`);
  console.log(`API URL: ${API_URL}`);
  console.log(`WebSocket URL: ${WS_URL}`);
  console.log(`Target Users: ${scenario.users}`);
  console.log(`Duration: ${scenario.duration}`);
  
  console.log('Redis Test Patterns:');
  Object.entries(CHANNEL_PATTERNS).forEach(([name, pattern]) => {
    console.log(`  ${name}: ${pattern.description} (${pattern.session_count} sessions, ${pattern.users_per_session} users/session)`);
  });

  // Health check
  const healthResponse = http.get(`${API_URL}${CONFIG.backends[BACKEND].health_endpoint}`);
  if (healthResponse.status !== 200) {
    throw new Error(`Backend health check failed: ${healthResponse.status}`);
  }
  
  console.log('Backend health check passed');
  console.log('WARNING: This test will create HIGH Redis pub/sub load');
  console.log('WARNING: Monitor Redis memory usage, channel count, and message throughput');
  
  return { backend: BACKEND, scenario: SCENARIO };
}

// Teardown function
export function teardown(data) {
  console.log(`Redis pub/sub stress test completed for ${data.backend} backend`);
  console.log(`Scenario: ${data.scenario}`);
  console.log('Key Redis metrics to review:');
  console.log('- redis_channel_latency: Time for messages to traverse Redis pub/sub');
  console.log('- message_delivery_latency: End-to-end message delivery time');
  console.log('- redis_messages_per_second: Total Redis throughput');
  console.log('- active_redis_channels: Number of active session channels');
  console.log('- message_broadcast_fanout: Redis message distribution efficiency');
}