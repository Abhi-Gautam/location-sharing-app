import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import http from 'k6/http';

// Metrics
const broadcastLatency = new Trend('broadcast_latency_ms');
const messagesSent = new Counter('broadcast_messages_sent');
const messagesReceived = new Counter('broadcast_messages_received');
const connectionSuccess = new Rate('connection_success_rate');

// Test configuration
const CONFIG = JSON.parse(open('../config/test-scenarios.json'));
const BACKEND = __ENV.BACKEND || 'rust';
const API_URL = __ENV.API_URL || CONFIG.backends[BACKEND].api_url;
const WS_URL = __ENV.WS_URL || CONFIG.backends[BACKEND].ws_url;

// Test parameters - BEAM vs Redis fan-out efficiency
const LISTENERS_PER_SESSION = 100;  // Recipients in each session
const BROADCASTERS = 10;           // Users sending messages
const TOTAL_VUS = LISTENERS_PER_SESSION + BROADCASTERS;
const MESSAGES_PER_BROADCASTER = 50;
const MESSAGE_INTERVAL_MS = 100; // Send fast to stress the pub/sub

export const options = {
  scenarios: {
    fanout_test: {
      executor: 'per-vu-iterations',
      vus: TOTAL_VUS,
      iterations: 1,
      maxDuration: '2m',
    },
  },
  thresholds: {
    'connection_success_rate': ['rate>0.95'],
    'broadcast_latency_ms': ['p(95)<100'],
  },
};

let globalSession = null;
let messageTimestamps = new Map();

function setupSession() {
  const headers = { 'Content-Type': 'application/json' };
  
  // Create session
  const sessionResponse = http.post(
    `${API_URL}/api/sessions`,
    JSON.stringify({ name: 'FanOutTest', expires_in_minutes: 10 }),
    { headers }
  );
  
  if (sessionResponse.status !== 200 && sessionResponse.status !== 201) {
    throw new Error(`Failed to create session: ${sessionResponse.status}`);
  }
  
  return JSON.parse(sessionResponse.body).session_id;
}

function joinSession(sessionId, userId) {
  const headers = { 'Content-Type': 'application/json' };
  
  const joinResponse = http.post(
    `${API_URL}/api/sessions/${sessionId}/join`,
    JSON.stringify({ display_name: userId, avatar_color: '#FF0000' }),
    { headers }
  );
  
  if (joinResponse.status !== 200 && joinResponse.status !== 201) {
    throw new Error(`Failed to join session: ${joinResponse.status}`);
  }
  
  return JSON.parse(joinResponse.body);
}

export default function () {
  const vuId = __VU;
  const isBroadcaster = vuId <= BROADCASTERS;
  const userId = `User_${vuId}`;
  
  // Single session for all users - maximum fan-out
  if (!globalSession) {
    globalSession = setupSession();
  }
  
  const joinData = joinSession(globalSession, userId);
  const wsToken = joinData.websocket_token;
  
  // Connect to WebSocket
  let wsUrl;
  if (BACKEND === 'rust') {
    wsUrl = `${WS_URL}/ws?token=${wsToken}`;
  } else {
    wsUrl = `${WS_URL}?token=${wsToken}`;
  }
  
  console.log(`[${userId}] Connecting as ${isBroadcaster ? 'BROADCASTER' : 'LISTENER'}`);
  
  const response = ws.connect(wsUrl, {}, function (socket) {
    connectionSuccess.add(true);
    
    // Elixir join
    if (BACKEND === 'elixir') {
      socket.send(JSON.stringify({
        topic: `location:${globalSession}`,
        event: 'phx_join',
        payload: { user_id: joinData.user_id },
        ref: `join_${Date.now()}`
      }));
    }
    
    // Message handler - track broadcast latency
    socket.on('message', function (data) {
      try {
        const message = JSON.parse(data);
        const messageId = message.ref || message.payload?.ref;
        
        if (messageId && messageTimestamps.has(messageId)) {
          const latency = Date.now() - messageTimestamps.get(messageId);
          broadcastLatency.add(latency);
          messagesReceived.add(1);
          
          if (latency > 50) {
            console.log(`[${userId}] HIGH LATENCY: ${latency}ms for message ${messageId}`);
          }
        }
      } catch (e) {}
    });
    
    socket.on('error', function (e) {
      console.error(`[${userId}] WebSocket error: ${e.error()}`);
    });
    
    if (isBroadcaster) {
      // BROADCASTER: Send rapid location updates to stress pub/sub
      console.log(`[${userId}] Starting broadcast of ${MESSAGES_PER_BROADCASTER} messages`);
      
      for (let i = 0; i < MESSAGES_PER_BROADCASTER; i++) {
        const messageId = `${userId}_${i}_${Date.now()}`;
        const timestamp = Date.now();
        messageTimestamps.set(messageId, timestamp);
        
        let message;
        if (BACKEND === 'rust') {
          message = JSON.stringify({
            type: 'location_update',
            data: {
              lat: 37.7749 + Math.random() * 0.01,
              lng: -122.4194 + Math.random() * 0.01,
              accuracy: 5,
              timestamp: new Date().toISOString()
            },
            ref: messageId
          });
        } else {
          message = JSON.stringify({
            topic: `location:${globalSession}`,
            event: 'location_update',
            payload: {
              user_id: joinData.user_id,
              lat: 37.7749 + Math.random() * 0.01,
              lng: -122.4194 + Math.random() * 0.01,
              accuracy: 5,
              timestamp: new Date().toISOString(),
              ref: messageId
            },
            ref: messageId
          });
        }
        
        socket.send(message);
        messagesSent.add(1);
        
        // High frequency to stress the system
        sleep(MESSAGE_INTERVAL_MS / 1000);
      }
      
      console.log(`[${userId}] Completed broadcasting ${MESSAGES_PER_BROADCASTER} messages`);
    } else {
      // LISTENER: Just receive messages and measure latency
      console.log(`[${userId}] Listening for broadcast messages...`);
      sleep(15); // Listen for 15 seconds
    }
    
    socket.close();
  });
  
  check(response, {
    'websocket connection established': (r) => r && r.status === 101,
  });
  
  if (!response || response.status !== 101) {
    connectionSuccess.add(false);
    console.error(`[${userId}] Connection failed`);
  }
}

export function setup() {
  console.log(`=== BROADCAST FAN-OUT TEST ===`);
  console.log(`Backend: ${BACKEND}`);
  console.log(`Architecture: ${BACKEND === 'rust' ? 'Redis pub/sub' : 'BEAM processes'}`);
  console.log(`Listeners per session: ${LISTENERS_PER_SESSION}`);
  console.log(`Broadcasters: ${BROADCASTERS}`);
  console.log(`Messages per broadcaster: ${MESSAGES_PER_BROADCASTER}`);
  console.log(`Total broadcast messages: ${BROADCASTERS * MESSAGES_PER_BROADCASTER}`);
  console.log(`Expected fan-out: ${LISTENERS_PER_SESSION} recipients per message`);
  console.log(`Message interval: ${MESSAGE_INTERVAL_MS}ms`);
  
  // Health check
  const healthResponse = http.get(`${API_URL}${CONFIG.backends[BACKEND].health_endpoint}`);
  if (healthResponse.status !== 200) {
    throw new Error(`Backend health check failed: ${healthResponse.status}`);
  }
  
  return { backend: BACKEND };
}

export function teardown(data) {
  console.log(`=== FAN-OUT TEST COMPLETE ===`);
  console.log(`Architecture tested: ${data.backend === 'rust' ? 'Redis pub/sub' : 'BEAM processes'}`);
  console.log(`Check broadcast_latency_ms metric for fan-out efficiency`);
}