/**
 * K6 WebSocket Load Testing Script for Phoenix Channels
 * 
 * Tests:
 * - WebSocket connection to Phoenix channels
 * - Real-time location updates
 * - Connection stability under load
 * - Message throughput and latency
 */

import ws from 'k6/ws';
import { check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
const connectionErrors = new Counter('websocket_connection_errors');
const messagesSent = new Counter('websocket_messages_sent');
const messagesReceived = new Counter('websocket_messages_received');
const connectionSuccess = new Rate('websocket_connection_success');
const messageLatency = new Trend('websocket_message_latency');

// Test configuration
export let options = {
  scenarios: {
    // Light load scenario
    light_load: {
      executor: 'constant-vus',
      vus: 10,
      duration: '2m',
      tags: { scenario: 'light' },
    },
    // Medium load scenario  
    medium_load: {
      executor: 'ramping-vus',
      startVUs: 10,
      stages: [
        { duration: '1m', target: 50 },
        { duration: '3m', target: 50 },
        { duration: '1m', target: 0 },
      ],
      tags: { scenario: 'medium' },
    },
    // Stress test scenario
    stress_load: {
      executor: 'ramping-vus', 
      startVUs: 50,
      stages: [
        { duration: '2m', target: 100 },
        { duration: '5m', target: 200 },
        { duration: '2m', target: 300 },
        { duration: '3m', target: 300 },
        { duration: '2m', target: 0 },
      ],
      tags: { scenario: 'stress' },
    },
  },
  thresholds: {
    websocket_connection_success: ['rate>0.95'],
    websocket_message_latency: ['p(95)<500'],
    websocket_connection_errors: ['count<10'],
  },
};

// Base configuration
const API_BASE_URL = __ENV.API_URL || 'http://localhost:4000/api';
const WS_BASE_URL = __ENV.WS_URL || 'ws://localhost:4000/socket/websocket';

export default function () {
  // Create a test session first
  const sessionData = createTestSession();
  if (!sessionData) {
    connectionErrors.add(1);
    return;
  }

  // Join the session as a participant
  const participantData = joinSession(sessionData.session_id);
  if (!participantData) {
    connectionErrors.add(1);
    return;
  }

  // Connect to WebSocket channel
  connectToLocationChannel(sessionData.session_id, participantData);
}

function createTestSession() {
  try {
    const sessionName = `K6 Test Session ${Math.random().toString(36).substr(2, 9)}`;
    const response = http.post(`${API_BASE_URL}/sessions`, JSON.stringify({
      name: sessionName
    }), {
      headers: { 'Content-Type': 'application/json' },
    });

    const success = check(response, {
      'session created': (r) => r.status === 201,
      'session has id': (r) => r.json('session_id') !== undefined,
    });

    if (success) {
      return response.json();
    }
  } catch (error) {
    console.error('Failed to create session:', error);
  }
  return null;
}

function joinSession(sessionId) {
  try {
    const displayName = `K6User${Math.random().toString(36).substr(2, 6)}`;
    const response = http.post(`${API_BASE_URL}/sessions/${sessionId}/participants`, JSON.stringify({
      display_name: displayName
    }), {
      headers: { 'Content-Type': 'application/json' },
    });

    const success = check(response, {
      'participant joined': (r) => r.status === 201,
      'participant has token': (r) => r.json('token') !== undefined,
    });

    if (success) {
      return response.json();
    }
  } catch (error) {
    console.error('Failed to join session:', error);
  }
  return null;
}

function connectToLocationChannel(sessionId, participantData) {
  const wsUrl = `${WS_BASE_URL}?token=${participantData.token}`;
  
  const response = ws.connect(wsUrl, {
    headers: {
      'Authorization': `Bearer ${participantData.token}`,
    },
  }, function (socket) {
    
    // Track connection success
    connectionSuccess.add(1);
    
    let messageCount = 0;
    let startTime = Date.now();
    
    // Phoenix channel join message
    const joinMessage = {
      topic: `location:${sessionId}`,
      event: 'phx_join',
      payload: {},
      ref: Math.random().toString(36).substr(2, 9)
    };

    socket.on('open', () => {
      console.log(`Connected to WebSocket for session ${sessionId}`);
      socket.send(JSON.stringify(joinMessage));
    });

    socket.on('message', (message) => {
      try {
        const data = JSON.parse(message);
        messagesReceived.add(1);
        
        // Calculate latency for location updates
        if (data.event === 'location_update' && data.payload && data.payload.timestamp) {
          const messageTime = new Date(data.payload.timestamp).getTime();
          const latency = Date.now() - messageTime;
          messageLatency.add(latency);
        }
        
        // Handle successful channel join
        if (data.event === 'phx_reply' && data.payload.status === 'ok') {
          console.log(`Successfully joined location channel for session ${sessionId}`);
          startLocationUpdates(socket, sessionId);
        }
        
      } catch (error) {
        console.error('Error parsing WebSocket message:', error);
      }
    });

    socket.on('error', (error) => {
      console.error('WebSocket error:', error);
      connectionErrors.add(1);
    });

    socket.on('close', () => {
      console.log(`WebSocket connection closed for session ${sessionId}`);
    });
    
    // Keep connection alive and send periodic updates
    socket.setTimeout(() => {
      // Send ping every 30 seconds
      const pingMessage = {
        topic: `location:${sessionId}`,
        event: 'ping',
        payload: {},
        ref: Math.random().toString(36).substr(2, 9)
      };
      socket.send(JSON.stringify(pingMessage));
    }, 30000);
    
  });

  check(response, { 'WebSocket connection established': (r) => r && r.url === wsUrl });
}

function startLocationUpdates(socket, sessionId) {
  // Simulate location updates every 2 seconds
  const locationUpdateInterval = setInterval(() => {
    const locationUpdate = {
      topic: `location:${sessionId}`,
      event: 'location_update',
      payload: {
        lat: 37.7749 + (Math.random() - 0.5) * 0.01, // Random location around SF
        lng: -122.4194 + (Math.random() - 0.5) * 0.01,
        accuracy: Math.random() * 20 + 5, // 5-25m accuracy
        timestamp: new Date().toISOString()
      },
      ref: Math.random().toString(36).substr(2, 9)
    };
    
    socket.send(JSON.stringify(locationUpdate));
    messagesSent.add(1);
    
  }, 2000);
  
  // Stop location updates after test duration
  socket.setTimeout(() => {
    clearInterval(locationUpdateInterval);
  }, 180000); // 3 minutes
}

export function handleSummary(data) {
  return {
    'websocket-load-results.json': JSON.stringify(data, null, 2),
    'websocket-load-summary.txt': generateTextSummary(data),
  };
}

function generateTextSummary(data) {
  const summary = `
K6 WebSocket Load Test Results
==============================

Test Duration: ${data.metrics.iteration_duration.avg}ms average
Total Connections: ${data.metrics.iterations.count}
Connection Success Rate: ${(data.metrics.websocket_connection_success.rate * 100).toFixed(2)}%
Connection Errors: ${data.metrics.websocket_connection_errors.count}

Messages:
- Sent: ${data.metrics.websocket_messages_sent.count}
- Received: ${data.metrics.websocket_messages_received.count}

Message Latency:
- Average: ${data.metrics.websocket_message_latency.avg.toFixed(2)}ms
- 95th Percentile: ${data.metrics.websocket_message_latency['p(95)'].toFixed(2)}ms
- Max: ${data.metrics.websocket_message_latency.max.toFixed(2)}ms

Scenarios:
${Object.entries(data.metrics)
  .filter(([key]) => key.includes('scenario:'))
  .map(([key, value]) => `- ${key}: ${value.count} iterations`)
  .join('\n')}

Test completed at: ${new Date().toISOString()}
`;

  return summary;
}