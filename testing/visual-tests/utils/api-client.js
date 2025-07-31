/**
 * API Client - Wrapper for Location Sharing REST API endpoints
 * 
 * Provides convenient methods to interact with the backend API
 * with proper error handling and response validation.
 */

const chalk = require('chalk');

class APIClient {
  constructor(baseUrl) {
    this.baseUrl = baseUrl.replace(/\/+$/, ''); // Remove trailing slashes
    this.apiUrl = `${this.baseUrl}/api`;
    this.healthUrl = this.baseUrl;
  }

  /**
   * Generic HTTP request method
   */
  async request(url, options = {}) {
    const {
      method = 'GET',
      headers = {},
      body = null,
      timeout = 30000
    } = options;

    const requestOptions = {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      },
      signal: AbortSignal.timeout(timeout)
    };

    if (body && method !== 'GET') {
      requestOptions.body = typeof body === 'string' ? body : JSON.stringify(body);
    }

    try {
      console.log(chalk.gray(`🌐 ${method} ${url}`));
      const response = await fetch(url, requestOptions);
      
      const responseData = {
        status: response.status,
        statusText: response.statusText,
        ok: response.ok,
        headers: Object.fromEntries(response.headers.entries())
      };

      // Try to parse JSON response
      let data = null;
      const contentType = response.headers.get('content-type');
      if (contentType && contentType.includes('application/json')) {
        try {
          data = await response.json();
        } catch (parseError) {
          console.warn(chalk.yellow(`⚠️  Failed to parse JSON response: ${parseError.message}`));
          data = await response.text();
        }
      } else {
        data = await response.text();
      }

      responseData.data = data;

      if (!response.ok) {
        const error = new Error(`HTTP ${response.status}: ${response.statusText}`);
        error.response = responseData;
        throw error;
      }

      console.log(chalk.green(`✅ ${method} ${url} - ${response.status}`));
      return responseData;

    } catch (error) {
      if (error.name === 'AbortError') {
        console.error(chalk.red(`❌ Request timeout: ${method} ${url}`));
        throw new Error(`Request timeout after ${timeout}ms`);
      }
      
      console.error(chalk.red(`❌ Request failed: ${method} ${url} - ${error.message}`));
      throw error;
    }
  }

  // Health Check endpoints

  /**
   * Basic health check
   */
  async healthCheck() {
    const response = await this.request(`${this.healthUrl}/health`);
    return response.data;
  }

  /**
   * Detailed health check
   */
  async detailedHealthCheck() {
    const response = await this.request(`${this.healthUrl}/health/detailed`);
    return response.data;
  }

  /**
   * Kubernetes readiness probe
   */
  async readinessCheck() {
    const response = await this.request(`${this.healthUrl}/health/ready`);
    return response.data;
  }

  /**
   * Kubernetes liveness probe
   */
  async livenessCheck() {
    const response = await this.request(`${this.healthUrl}/health/live`);
    return response.data;
  }

  // Session Management endpoints

  /**
   * Create a new session
   * @param {string} name - Session name
   * @returns {Object} Session object with session_id, name, expires_at, share_url
   */
  async createSession(name) {
    console.log(chalk.blue(`📋 Creating session: "${name}"`));
    
    const response = await this.request(`${this.apiUrl}/sessions`, {
      method: 'POST',
      body: { name }
    });

    const session = response.data;
    console.log(chalk.green(`✅ Session created: ${session.session_id}`));
    
    return session;
  }

  /**
   * Get session details
   * @param {string} sessionId - Session ID
   * @returns {Object} Session object
   */
  async getSession(sessionId) {
    console.log(chalk.blue(`📋 Getting session: ${sessionId}`));
    
    const response = await this.request(`${this.apiUrl}/sessions/${sessionId}`);
    
    console.log(chalk.green(`✅ Session retrieved: ${sessionId}`));
    return response.data;
  }

  /**
   * Delete/end a session
   * @param {string} sessionId - Session ID
   * @returns {boolean} Success status
   */
  async deleteSession(sessionId) {
    console.log(chalk.blue(`🗑️  Deleting session: ${sessionId}`));
    
    try {
      await this.request(`${this.apiUrl}/sessions/${sessionId}`, {
        method: 'DELETE'
      });
      
      console.log(chalk.green(`✅ Session deleted: ${sessionId}`));
      return true;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to delete session ${sessionId}: ${error.message}`));
      return false;
    }
  }

  // Participant Management endpoints

  /**
   * Join a session
   * @param {string} sessionId - Session ID
   * @param {string} displayName - Participant display name
   * @param {string} avatarColor - Avatar color (hex)
   * @returns {Object} Join response with token and participant info
   */
  async joinSession(sessionId, displayName, avatarColor = '#4299e1') {
    console.log(chalk.blue(`👤 Joining session ${sessionId} as "${displayName}"`));
    
    const response = await this.request(`${this.apiUrl}/sessions/${sessionId}/join`, {
      method: 'POST',
      body: {
        display_name: displayName,
        avatar_color: avatarColor
      }
    });

    const result = response.data;
    console.log(chalk.green(`✅ Joined session as user: ${result.user_id}`));
    
    return result;
  }

  /**
   * Leave a session
   * @param {string} sessionId - Session ID
   * @param {string} userId - User ID
   * @returns {boolean} Success status
   */
  async leaveSession(sessionId, userId) {
    console.log(chalk.blue(`👋 Leaving session ${sessionId} for user ${userId}`));
    
    try {
      await this.request(`${this.apiUrl}/sessions/${sessionId}/participants/${userId}`, {
        method: 'DELETE'
      });
      
      console.log(chalk.green(`✅ Left session: ${sessionId}`));
      return true;
    } catch (error) {
      console.error(chalk.red(`❌ Failed to leave session ${sessionId}: ${error.message}`));
      return false;
    }
  }

  /**
   * List all participants in a session
   * @param {string} sessionId - Session ID
   * @returns {Array} List of participants
   */
  async listParticipants(sessionId) {
    console.log(chalk.blue(`👥 Listing participants for session: ${sessionId}`));
    
    const response = await this.request(`${this.apiUrl}/sessions/${sessionId}/participants`);
    
    const participants = response.data;
    console.log(chalk.green(`✅ Found ${participants.length} participants`));
    
    return participants;
  }

  // Utility methods

  /**
   * Check if backend is accessible
   * @returns {boolean} True if backend is healthy
   */
  async isHealthy() {
    try {
      await this.healthCheck();
      return true;
    } catch (error) {
      console.error(chalk.red(`❌ Backend health check failed: ${error.message}`));
      return false;
    }
  }

  /**
   * Wait for backend to become healthy
   * @param {number} timeout - Timeout in milliseconds
   * @param {number} interval - Check interval in milliseconds
   * @returns {boolean} True if backend became healthy
   */
  async waitForHealthy(timeout = 60000, interval = 2000) {
    console.log(chalk.blue('⏳ Waiting for backend to become healthy...'));
    
    const startTime = Date.now();
    
    while (Date.now() - startTime < timeout) {
      if (await this.isHealthy()) {
        console.log(chalk.green('✅ Backend is healthy'));
        return true;
      }
      
      console.log(chalk.gray(`🔄 Backend not ready, retrying in ${interval/1000}s...`));
      await new Promise(resolve => setTimeout(resolve, interval));
    }
    
    console.error(chalk.red(`❌ Backend did not become healthy within ${timeout/1000}s`));
    return false;
  }

  /**
   * Create multiple test sessions
   * @param {number} count - Number of sessions to create
   * @param {string} namePrefix - Session name prefix
   * @returns {Array} Array of created sessions
   */
  async createTestSessions(count, namePrefix = 'Test Session') {
    console.log(chalk.blue(`📋 Creating ${count} test sessions...`));
    
    const sessions = [];
    
    for (let i = 1; i <= count; i++) {
      try {
        const session = await this.createSession(`${namePrefix} ${i}`);
        sessions.push({
          ...session,
          index: i - 1,
          participants: []
        });
      } catch (error) {
        console.error(chalk.red(`❌ Failed to create session ${i}: ${error.message}`));
        throw error;
      }
    }
    
    console.log(chalk.green(`✅ Created ${sessions.length} test sessions`));
    return sessions;
  }

  /**
   * Join multiple users to sessions
   * @param {Array} sessions - Array of session objects
   * @param {Array} users - Array of user objects with displayName and avatarColor
   * @returns {Array} Array of join results
   */
  async joinUsersToSessions(sessions, users) {
    console.log(chalk.blue(`👥 Joining ${users.length} users to ${sessions.length} sessions...`));
    
    const results = [];
    const usersPerSession = Math.ceil(users.length / sessions.length);
    
    let userIndex = 0;
    for (const session of sessions) {
      const sessionUsers = users.slice(userIndex, userIndex + usersPerSession);
      
      for (const user of sessionUsers) {
        try {
          const result = await this.joinSession(
            session.session_id,
            user.displayName,
            user.avatarColor
          );
          
          results.push({
            ...result,
            sessionId: session.session_id,
            sessionIndex: session.index,
            user: user
          });
          
          session.participants.push(result);
          
        } catch (error) {
          console.error(chalk.red(`❌ Failed to join ${user.displayName} to session: ${error.message}`));
          throw error;
        }
      }
      
      userIndex += sessionUsers.length;
    }
    
    console.log(chalk.green(`✅ Joined ${results.length} users to sessions`));
    return results;
  }

  /**
   * Clean up test sessions
   * @param {Array} sessions - Array of session objects to delete
   * @returns {number} Number of sessions successfully deleted
   */
  async cleanupTestSessions(sessions) {
    console.log(chalk.blue(`🧹 Cleaning up ${sessions.length} test sessions...`));
    
    let deletedCount = 0;
    
    for (const session of sessions) {
      if (await this.deleteSession(session.session_id)) {
        deletedCount++;
      }
    }
    
    console.log(chalk.green(`✅ Cleaned up ${deletedCount}/${sessions.length} sessions`));
    return deletedCount;
  }
}

module.exports = APIClient;