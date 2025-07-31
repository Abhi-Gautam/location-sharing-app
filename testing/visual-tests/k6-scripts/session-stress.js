/**
 * K6 Session Stress Testing Script
 * 
 * Tests:
 * - Session creation under load
 * - Participant joining stress
 * - Database performance under concurrent operations
 * - API response times during high load
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics
const sessionCreationErrors = new Counter('session_creation_errors');
const participantJoinErrors = new Counter('participant_join_errors');
const sessionCreationSuccess = new Rate('session_creation_success');
const participantJoinSuccess = new Rate('participant_join_success');
const sessionCreationTime = new Trend('session_creation_time');
const participantJoinTime = new Trend('participant_join_time');

// Test configuration - Progressive load testing
export let options = {
  scenarios: {
    // Session creation stress
    session_creation_stress: {
      executor: 'ramping-vus',
      exec: 'sessionCreationTest',
      startVUs: 1,
      stages: [
        { duration: '30s', target: 5 },   // Warm up
        { duration: '1m', target: 20 },   // Light load
        { duration: '2m', target: 50 },   // Medium load
        { duration: '3m', target: 100 },  // Heavy load
        { duration: '2m', target: 150 },  // Stress load
        { duration: '1m', target: 200 },  // Peak stress
        { duration: '2m', target: 0 },    // Cool down
      ],
      tags: { test_type: 'session_creation' },
    },
    
    // Participant joining stress
    participant_join_stress: {
      executor: 'ramping-vus',
      exec: 'participantJoinTest', 
      startVUs: 1,
      stages: [
        { duration: '1m', target: 10 },   // Create baseline sessions
        { duration: '2m', target: 50 },   // Medium participant load
        { duration: '3m', target: 150 },  // Heavy participant load
        { duration: '2m', target: 300 },  // Stress participant load
        { duration: '1m', target: 500 },  // Peak participant stress
        { duration: '2m', target: 0 },    // Cool down
      ],
      tags: { test_type: 'participant_join' },
    },
    
    // Mixed operations stress
    mixed_operations: {
      executor: 'constant-vus',
      exec: 'mixedOperationsTest',
      vus: 50,
      duration: '5m',
      tags: { test_type: 'mixed_operations' },
    },
  },
  
  thresholds: {
    // Session creation thresholds
    session_creation_success: ['rate>0.95'],
    session_creation_time: ['p(95)<2000', 'p(99)<3000'],
    session_creation_errors: ['count<20'],
    
    // Participant join thresholds
    participant_join_success: ['rate>0.95'],
    participant_join_time: ['p(95)<1500', 'p(99)<2500'],
    participant_join_errors: ['count<30'],
    
    // General HTTP thresholds
    http_req_duration: ['p(95)<3000'],
    http_req_failed: ['rate<0.05'],
  },
};

const API_BASE_URL = __ENV.API_URL || 'http://localhost:4000/api';

// Global session storage for reuse
let globalSessions = [];

export function sessionCreationTest() {
  const sessionName = `Stress Test Session ${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  
  const startTime = Date.now();
  const response = http.post(`${API_BASE_URL}/sessions`, JSON.stringify({
    name: sessionName,
    description: `Load test session created by K6 VU ${__VU}`
  }), {
    headers: { 'Content-Type': 'application/json' },
    timeout: '30s',
  });
  
  const duration = Date.now() - startTime;
  sessionCreationTime.add(duration);
  
  const success = check(response, {
    'session creation status is 201': (r) => r.status === 201,
    'session has valid ID': (r) => {
      try {
        const data = r.json();
        return data.session_id && data.session_id.length > 0;
      } catch (e) {
        return false;
      }
    },
    'session creation time < 5s': () => duration < 5000,
  });
  
  if (success) {
    sessionCreationSuccess.add(1);
    // Store session for potential reuse
    try {
      const sessionData = response.json();
      globalSessions.push(sessionData);
    } catch (e) {
      console.error('Failed to parse session response:', e);
    }
  } else {
    sessionCreationErrors.add(1);
    console.error(`Session creation failed: ${response.status} - ${response.body}`);
  }
  
  sleep(0.5); // Brief pause between requests
}

export function participantJoinTest() {
  // Get or create a session to join
  let sessionId;
  
  if (globalSessions.length > 0) {
    // Use existing session
    const randomSession = globalSessions[Math.floor(Math.random() * globalSessions.length)];
    sessionId = randomSession.session_id;
  } else {
    // Create a new session first
    const sessionResponse = http.post(`${API_BASE_URL}/sessions`, JSON.stringify({
      name: `Participant Test Session ${Date.now()}`
    }), {
      headers: { 'Content-Type': 'application/json' },
      timeout: '10s',
    });
    
    if (sessionResponse.status === 201) {
      try {
        sessionId = sessionResponse.json().session_id;
        globalSessions.push(sessionResponse.json());
      } catch (e) {
        console.error('Failed to create session for participant test:', e);
        return;
      }
    } else {
      console.error('Failed to create session for participant test');
      return;
    }
  }
  
  // Join the session as a participant
  const displayName = `StressUser-${__VU}-${Date.now()}`;
  
  const startTime = Date.now();
  const response = http.post(`${API_BASE_URL}/sessions/${sessionId}/participants`, JSON.stringify({
    display_name: displayName,
    avatar_color: generateRandomColor()
  }), {
    headers: { 'Content-Type': 'application/json' },
    timeout: '20s',
  });
  
  const duration = Date.now() - startTime;
  participantJoinTime.add(duration);
  
  const success = check(response, {
    'participant join status is 201': (r) => r.status === 201,
    'participant has valid token': (r) => {
      try {
        const data = r.json();
        return data.token && data.token.length > 0;
      } catch (e) {
        return false;
      }
    },
    'participant join time < 3s': () => duration < 3000,
  });
  
  if (success) {
    participantJoinSuccess.add(1);
  } else {
    participantJoinErrors.add(1);
    console.error(`Participant join failed: ${response.status} - ${response.body}`);
  }
  
  sleep(0.3); // Brief pause
}

export function mixedOperationsTest() {
  const operations = ['create_session', 'join_session', 'health_check', 'get_session'];
  const operation = operations[Math.floor(Math.random() * operations.length)];
  
  switch (operation) {
    case 'create_session':
      sessionCreationTest();
      break;
      
    case 'join_session':
      participantJoinTest();
      break;
      
    case 'health_check':
      healthCheckTest();
      break;
      
    case 'get_session':
      getSessionTest();
      break;
  }
  
  sleep(Math.random() * 2); // Random pause 0-2 seconds
}

function healthCheckTest() {
  const response = http.get(`${API_BASE_URL.replace('/api', '')}/health`, {
    timeout: '10s',
  });
  
  check(response, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 500ms': (r) => r.timings.duration < 500,
  });
}

function getSessionTest() {
  if (globalSessions.length === 0) return;
  
  const randomSession = globalSessions[Math.floor(Math.random() * globalSessions.length)];
  const response = http.get(`${API_BASE_URL}/sessions/${randomSession.session_id}`, {
    timeout: '10s',
  });
  
  check(response, {
    'get session status is 200': (r) => r.status === 200,
    'get session has valid data': (r) => {
      try {
        const data = r.json();
        return data.session_id === randomSession.session_id;
      } catch (e) {
        return false;
      }
    },
  });
}

function generateRandomColor() {
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
    '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
  ];
  return colors[Math.floor(Math.random() * colors.length)];
}

export function handleSummary(data) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  
  return {
    [`reports/session-stress-${timestamp}.json`]: JSON.stringify(data, null, 2),
    [`reports/session-stress-summary-${timestamp}.txt`]: generateStressSummary(data),
    stdout: generateConsoleSummary(data),
  };
}

function generateStressSummary(data) {
  const summary = `
K6 Session Stress Test Results
==============================
Test completed: ${new Date().toISOString()}

SESSION CREATION PERFORMANCE:
- Success Rate: ${(data.metrics.session_creation_success?.rate * 100 || 0).toFixed(2)}%
- Average Response Time: ${data.metrics.session_creation_time?.avg?.toFixed(2) || 'N/A'}ms
- 95th Percentile: ${data.metrics.session_creation_time?.['p(95)']?.toFixed(2) || 'N/A'}ms
- 99th Percentile: ${data.metrics.session_creation_time?.['p(99)']?.toFixed(2) || 'N/A'}ms
- Max Response Time: ${data.metrics.session_creation_time?.max?.toFixed(2) || 'N/A'}ms
- Total Errors: ${data.metrics.session_creation_errors?.count || 0}

PARTICIPANT JOIN PERFORMANCE:
- Success Rate: ${(data.metrics.participant_join_success?.rate * 100 || 0).toFixed(2)}%
- Average Response Time: ${data.metrics.participant_join_time?.avg?.toFixed(2) || 'N/A'}ms
- 95th Percentile: ${data.metrics.participant_join_time?.['p(95)']?.toFixed(2) || 'N/A'}ms
- 99th Percentile: ${data.metrics.participant_join_time?.['p(99)']?.toFixed(2) || 'N/A'}ms
- Max Response Time: ${data.metrics.participant_join_time?.max?.toFixed(2) || 'N/A'}ms
- Total Errors: ${data.metrics.participant_join_errors?.count || 0}

OVERALL HTTP PERFORMANCE:
- Request Success Rate: ${((1 - (data.metrics.http_req_failed?.rate || 0)) * 100).toFixed(2)}%
- Average Request Duration: ${data.metrics.http_req_duration?.avg?.toFixed(2) || 'N/A'}ms
- 95th Percentile Duration: ${data.metrics.http_req_duration?.['p(95)']?.toFixed(2) || 'N/A'}ms
- Total Requests: ${data.metrics.http_reqs?.count || 0}
- Requests per Second: ${data.metrics.http_reqs?.rate?.toFixed(2) || 'N/A'}

VIRTUAL USERS:
- Peak VUs: ${data.metrics.vus_max?.max || 0}
- Average VUs: ${data.metrics.vus?.avg?.toFixed(2) || 'N/A'}

TEST SCENARIOS:
${Object.entries(data.metrics)
  .filter(([key]) => key.includes('scenario:'))
  .map(([key, value]) => `- ${key}: ${value.count} iterations`)
  .join('\n') || 'No scenario metrics available'}

THRESHOLDS:
${Object.entries(data.thresholds || {})
  .map(([metric, result]) => `- ${metric}: ${result.ok ? '✅ PASS' : '❌ FAIL'}`)
  .join('\n') || 'No thresholds configured'}
`;

  return summary;
}

function generateConsoleSummary(data) {
  return `
🎯 Session Stress Test Complete!
Sessions Created: ${data.metrics.iterations?.count || 0}
Success Rate: ${((data.metrics.session_creation_success?.rate || 0) * 100).toFixed(1)}%
Peak Load: ${data.metrics.vus_max?.max || 0} concurrent users
`;
}