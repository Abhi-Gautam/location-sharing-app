import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';
import http from 'k6/http';

// Comparison-specific metrics
const backendResponseTime = new Trend('backend_response_time', true);
const backendThroughput = new Rate('backend_throughput_success');
const backendErrorRate = new Rate('backend_error_rate');
const backendMemoryEfficiency = new Gauge('backend_memory_efficiency');
const backendConcurrencyHandling = new Trend('backend_concurrency_handling');

// WebSocket performance comparison
const wsConnectionStability = new Rate('websocket_connection_stability');
const wsMessageLatency = new Trend('websocket_message_latency');
const wsBroadcastEfficiency = new Rate('websocket_broadcast_efficiency');
const wsConnectionOverhead = new Trend('websocket_connection_overhead');

// Database interaction comparison
const databaseQueryPerformance = new Trend('database_query_performance');
const databaseConnectionPoolUsage = new Gauge('database_connection_pool_usage');
const databaseTransactionRate = new Rate('database_transaction_success');

// Redis performance comparison
const redisOperationLatency = new Trend('redis_operation_latency');
const redisConnectionEfficiency = new Rate('redis_connection_efficiency');
const redisPubSubPerformance = new Trend('redis_pubsub_performance');
const redisMemoryUsage = new Gauge('redis_memory_usage');

// Load test configuration
const CONFIG = JSON.parse(open('../config/test-scenarios.json'));

// Test parameters - this test runs against BOTH backends simultaneously
const SCENARIO = __ENV.SCENARIO || 'backend_comparison';
const RUST_API_URL = __ENV.RUST_API_URL || 'http://rust-api:8000';
const RUST_WS_URL = __ENV.RUST_WS_URL || 'ws://rust-ws:8001';
const ELIXIR_API_URL = __ENV.ELIXIR_API_URL || 'http://elixir:4000';
const ELIXIR_WS_URL = __ENV.ELIXIR_WS_URL || 'ws://elixir:4000/socket/websocket';

const scenario = CONFIG.scenarios[SCENARIO];

export const options = {
  scenarios: {
    backend_comparison: {
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
    'backend_response_time': ['p95<1000'],
    'backend_throughput_success': ['rate>0.95'],
    'websocket_connection_stability': ['rate>0.98'],
    'database_query_performance': ['p95<500'],
    'redis_operation_latency': ['p95<100'],
  },
};

// Comparison test scenarios
const COMPARISON_SCENARIOS = {
  identical_load: {
    description: 'Identical operations on both backends',
    operations: ['create_session', 'join_session', 'location_updates', 'leave_session']
  },
  stress_comparison: {
    description: 'Progressive load increase to find breaking points',
    operations: ['burst_location_updates', 'concurrent_sessions', 'websocket_flood']
  },
  real_world_simulation: {
    description: 'Realistic usage patterns',
    operations: ['mixed_user_behavior', 'session_lifecycle', 'geographic_distribution']
  }
};

// Test data generators (consistent across backends)
function generateSessionName(backend) {
  const prefixes = ['Compare', 'Benchmark', 'Test', 'Load', 'Stress'];
  const activities = ['Rust', 'Elixir', 'Backend', 'Performance', 'Analysis'];
  const numbers = Math.floor(Math.random() * 10000);
  return `${backend.toUpperCase()}-${prefixes[Math.floor(Math.random() * prefixes.length)]} ${activities[Math.floor(Math.random() * activities.length)]} ${numbers}`;
}

function generateUserName(backend) {
  const firstNames = ['Compare', 'Bench', 'Test', 'Load', 'Stress', 'Perf', 'Analysis', 'Metric'];
  const lastNames = ['User', 'Client', 'Tester', 'Agent', 'Worker', 'Node', 'Instance', 'Process'];
  return `${backend.toUpperCase()}-${firstNames[Math.floor(Math.random() * firstNames.length)]} ${lastNames[Math.floor(Math.random() * lastNames.length)]} ${__VU}`;
}

function generateLocation() {
  // Use same location for fair comparison
  const baseLat = 37.7749;
  const baseLng = -122.4194;
  const range = 0.01; // Small range for consistent testing
  
  return {
    latitude: baseLat + (Math.random() - 0.5) * range,
    longitude: baseLng + (Math.random() - 0.5) * range,
  };
}

function generateAvatarColor() {
  const colors = ['#FF5733', '#33FF57', '#3357FF', '#FF33F1', '#F1FF33', '#33FFF1'];
  return colors[Math.floor(Math.random() * colors.length)];
}

// Backend operation functions
function createSessionOnBackend(backend, apiUrl) {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  const sessionPayload = {
    name: generateSessionName(backend),
    expires_in_minutes: 120,
  };

  const start = Date.now();
  const response = http.post(
    `${apiUrl}/api/sessions`,
    JSON.stringify(sessionPayload),
    { headers, tags: { backend: backend } }
  );
  
  const duration = Date.now() - start;
  backendResponseTime.add(duration, { backend: backend, operation: 'create_session' });
  
  const success = response.status === 200 || response.status === 201;
  backendThroughput.add(success, { backend: backend });
  backendErrorRate.add(!success, { backend: backend });
  databaseQueryPerformance.add(duration, { backend: backend, query_type: 'insert' });

  if (success) {
    const sessionData = JSON.parse(response.body);
    return {
      id: sessionData.session_id,
      name: sessionData.name,
      backend: backend
    };
  }

  return null;
}

function joinSessionOnBackend(backend, apiUrl, sessionId) {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  const joinPayload = {
    display_name: generateUserName(backend),
    avatar_color: generateAvatarColor(),
  };

  const start = Date.now();
  const response = http.post(
    `${apiUrl}/api/sessions/${sessionId}/join`,
    JSON.stringify(joinPayload),
    { headers, tags: { backend: backend } }
  );
  
  const duration = Date.now() - start;
  backendResponseTime.add(duration, { backend: backend, operation: 'join_session' });
  databaseQueryPerformance.add(duration, { backend: backend, query_type: 'insert_update' });

  const success = response.status === 200 || response.status === 201;
  backendThroughput.add(success, { backend: backend });
  backendErrorRate.add(!success, { backend: backend });

  if (success) {
    const joinData = JSON.parse(response.body);
    return {
      userId: joinData.user_id,
      wsToken: joinData.websocket_token,
      backend: backend
    };
  }

  return null;
}

function connectWebSocketToBackend(backend, wsUrl, sessionId, userId, wsToken) {
  let url;
  if (backend === 'rust') {
    url = `${wsUrl}/ws?session_id=${sessionId}&user_id=${userId}&token=${wsToken}`;
  } else {
    url = `${wsUrl}?session_id=${sessionId}&user_id=${userId}&token=${wsToken}`;
  }

  const connectStart = Date.now();
  
  return new Promise((resolve, reject) => {
    const response = ws.connect(url, {}, function (socket) {
      const connectDuration = Date.now() - connectStart;
      wsConnectionOverhead.add(connectDuration, { backend: backend });
      wsConnectionStability.add(true, { backend: backend });
      
      let messagesReceived = 0;
      let messagesSent = 0;
      const latencyMap = new Map();

      socket.on('message', function (message) {
        const receiveTime = Date.now();
        messagesReceived++;
        
        try {
          const data = JSON.parse(message);
          
          // Track message latency
          if (data.ref && latencyMap.has(data.ref)) {
            const sendTime = latencyMap.get(data.ref);
            const latency = receiveTime - sendTime;
            wsMessageLatency.add(latency, { backend: backend });
            redisPubSubPerformance.add(latency, { backend: backend });
            latencyMap.delete(data.ref);
          }
          
          // Track broadcast efficiency
          if (data.type === 'location_update' && data.data) {
            wsBroadcastEfficiency.add(true, { backend: backend });
          }
        } catch (e) {
          // Non-JSON message
        }
      });

      socket.on('error', function (e) {
        console.error(`[VU ${__VU}] ${backend} WebSocket error: ${e.error()}`);
        wsConnectionStability.add(false, { backend: backend });
      });

      socket.on('close', function () {
        console.log(`[VU ${__VU}] ${backend} WebSocket closed - sent: ${messagesSent}, received: ${messagesReceived}`);
      });

      // Send initial join message
      let joinMessage;
      const joinRef = `compare_join_${Date.now()}_${__VU}_${backend}`;
      
      if (backend === 'rust') {
        joinMessage = JSON.stringify({
          type: 'join_session',
          data: {
            session_id: sessionId,
            user_id: userId,
            comparison_test: true
          },
          ref: joinRef
        });
      } else {
        joinMessage = JSON.stringify({
          topic: `session:${sessionId}`,
          event: 'phx_join',
          payload: {
            user_id: userId,
            comparison_test: true
          },
          ref: joinRef
        });
      }

      const sendStart = Date.now();
      latencyMap.set(joinRef, sendStart);
      socket.send(joinMessage);
      messagesSent++;

      resolve({
        socket: socket,
        backend: backend,
        sessionId: sessionId,
        userId: userId,
        latencyMap: latencyMap,
        messagesSent: () => messagesSent,
        messagesReceived: () => messagesReceived
      });
    });

    if (!response || response.status !== 101) {
      wsConnectionStability.add(false, { backend: backend });
      reject(new Error(`${backend} WebSocket connection failed`));
    }
  });
}

function sendLocationUpdateComparison(connection) {
  const location = generateLocation();
  const timestamp = new Date().toISOString();
  const updateRef = `compare_update_${Date.now()}_${__VU}_${connection.backend}`;
  
  let locationMessage;
  if (connection.backend === 'rust') {
    locationMessage = JSON.stringify({
      type: 'location_update',
      data: {
        session_id: connection.sessionId,
        user_id: connection.userId,
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: timestamp,
        comparison_test: true
      },
      ref: updateRef
    });
  } else {
    locationMessage = JSON.stringify({
      topic: `session:${connection.sessionId}`,
      event: 'location_update',
      payload: {
        user_id: connection.userId,
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: timestamp,
        comparison_test: true
      },
      ref: updateRef
    });
  }

  const sendStart = Date.now();
  connection.latencyMap.set(updateRef, sendStart);
  connection.socket.send(locationMessage);
  
  redisOperationLatency.add(Date.now() - sendStart, { backend: connection.backend });
  return true;
}

// Main comparison test function
export default function () {
  console.log(`[VU ${__VU}] Starting backend comparison test...`);
  
  // Determine which backends to test (alternate between them)
  const backends = ['rust', 'elixir'];
  const selectedBackend = backends[__VU % backends.length];
  
  let apiUrl, wsUrl;
  if (selectedBackend === 'rust') {
    apiUrl = RUST_API_URL;
    wsUrl = RUST_WS_URL;
  } else {
    apiUrl = ELIXIR_API_URL;
    wsUrl = ELIXIR_WS_URL;
  }
  
  console.log(`[VU ${__VU}] Testing ${selectedBackend} backend`);
  
  // Phase 1: Session Creation Comparison
  console.log(`[VU ${__VU}] Phase 1: Creating session on ${selectedBackend}`);
  const session = createSessionOnBackend(selectedBackend, apiUrl);
  
  if (!session) {
    console.error(`[VU ${__VU}] Failed to create session on ${selectedBackend}, aborting`);
    return;
  }
  
  console.log(`[VU ${__VU}] Created session on ${selectedBackend}: ${session.id}`);
  
  // Phase 2: Session Join Comparison
  console.log(`[VU ${__VU}] Phase 2: Joining session on ${selectedBackend}`);
  const joinInfo = joinSessionOnBackend(selectedBackend, apiUrl, session.id);
  
  if (!joinInfo) {
    console.error(`[VU ${__VU}] Failed to join session on ${selectedBackend}, aborting`);
    return;
  }
  
  console.log(`[VU ${__VU}] Joined session on ${selectedBackend}: ${joinInfo.userId}`);
  
  // Phase 3: WebSocket Connection Comparison
  console.log(`[VU ${__VU}] Phase 3: Connecting WebSocket on ${selectedBackend}`);
  
  connectWebSocketToBackend(selectedBackend, wsUrl, session.id, joinInfo.userId, joinInfo.wsToken)
    .then(connection => {
      console.log(`[VU ${__VU}] WebSocket connected on ${selectedBackend}`);
      
      // Phase 4: Location Update Performance Comparison
      console.log(`[VU ${__VU}] Phase 4: Starting location updates on ${selectedBackend}`);
      
      let updateCount = 0;
      const maxUpdates = 50; // Consistent number for comparison
      
      const updateTimer = setInterval(() => {
        if (updateCount >= maxUpdates) {
          clearInterval(updateTimer);
          
          // Phase 5: Performance Summary
          const finalStats = {
            backend: selectedBackend,
            messagesSent: connection.messagesSent(),
            messagesReceived: connection.messagesReceived(),
            updateCount: updateCount
          };
          
          console.log(`[VU ${__VU}] ${selectedBackend} comparison complete:`, JSON.stringify(finalStats));
          connection.socket.close();
          return;
        }
        
        const success = sendLocationUpdateComparison(connection);
        if (success) {
          updateCount++;
          
          if (updateCount % 10 === 0) {
            console.log(`[VU ${__VU}] ${selectedBackend}: sent ${updateCount} location updates`);
          }
        }
      }, 1000); // 1 update per second for consistent comparison
      
      // Handle test duration
      setTimeout(() => {
        clearInterval(updateTimer);
        connection.socket.close();
      }, 60000); // 1 minute test duration
      
    })
    .catch(error => {
      console.error(`[VU ${__VU}] WebSocket connection failed on ${selectedBackend}: ${error.message}`);
    });
  
  // Keep the test running
  sleep(70); // 70 seconds to allow completion
}

// Performance analysis functions
function analyzeBackendPerformance() {
  // This would typically be done in post-processing
  console.log('Backend performance analysis should be done using the tagged metrics');
  console.log('Key metrics to compare:');
  console.log('- backend_response_time by backend tag');
  console.log('- websocket_message_latency by backend tag');
  console.log('- redis_operation_latency by backend tag');
  console.log('- database_query_performance by backend tag');
}

// Setup function
export function setup() {
  console.log(`Starting ${SCENARIO} backend comparison test`);
  console.log(`Rust API URL: ${RUST_API_URL}`);
  console.log(`Rust WebSocket URL: ${RUST_WS_URL}`);
  console.log(`Elixir API URL: ${ELIXIR_API_URL}`);
  console.log(`Elixir WebSocket URL: ${ELIXIR_WS_URL}`);
  console.log(`Target Users: ${scenario.users}`);
  console.log(`Duration: ${scenario.duration}`);
  
  // Health check both backends
  const rustHealthResponse = http.get(`${RUST_API_URL}/health`);
  const elixirHealthResponse = http.get(`${ELIXIR_API_URL}/health`);
  
  if (rustHealthResponse.status !== 200) {
    throw new Error(`Rust backend health check failed: ${rustHealthResponse.status}`);
  }
  
  if (elixirHealthResponse.status !== 200) {
    throw new Error(`Elixir backend health check failed: ${elixirHealthResponse.status}`);
  }
  
  console.log('Both backend health checks passed');
  console.log('WARNING: This test compares performance between Rust and Elixir backends');
  console.log('WARNING: Ensure both backends have identical configurations');
  console.log('WARNING: Monitor system resources for both backends simultaneously');
  
  return { rust_api: RUST_API_URL, elixir_api: ELIXIR_API_URL, scenario: SCENARIO };
}

// Teardown function
export function teardown(data) {
  console.log(`Backend comparison test completed`);
  console.log(`Scenario: ${data.scenario}`);
  console.log('Backend Performance Comparison Summary:');
  console.log('=====================================');
  console.log('Key metrics to analyze in Grafana/Prometheus:');
  console.log('');
  console.log('Response Time Comparison:');
  console.log('- backend_response_time{backend="rust"} vs backend_response_time{backend="elixir"}');
  console.log('');
  console.log('WebSocket Performance:');
  console.log('- websocket_message_latency{backend="rust"} vs websocket_message_latency{backend="elixir"}');
  console.log('- websocket_connection_stability{backend="rust"} vs websocket_connection_stability{backend="elixir"}');
  console.log('');
  console.log('Database Performance:');
  console.log('- database_query_performance{backend="rust"} vs database_query_performance{backend="elixir"}');
  console.log('');
  console.log('Redis Performance:');
  console.log('- redis_operation_latency{backend="rust"} vs redis_operation_latency{backend="elixir"}');
  console.log('- redis_pubsub_performance{backend="rust"} vs redis_pubsub_performance{backend="elixir"}');
  console.log('');
  console.log('Throughput and Error Rates:');
  console.log('- backend_throughput_success{backend="rust"} vs backend_throughput_success{backend="elixir"}');
  console.log('- backend_error_rate{backend="rust"} vs backend_error_rate{backend="elixir"}');
  console.log('');
  console.log('Next Steps:');
  console.log('1. Create Grafana dashboard with side-by-side backend comparison');
  console.log('2. Analyze percentile distributions (p50, p95, p99) for each backend');
  console.log('3. Compare resource utilization (CPU, Memory, Network)');
  console.log('4. Test different load levels to find performance characteristics');
  console.log('5. Measure cost-performance ratio for production deployment');
}