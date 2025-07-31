/**
 * WebSocket Client - Phoenix Channels client for location sharing
 * 
 * Handles WebSocket connections to Phoenix channels for real-time
 * location updates and session communication.
 */

const { Socket } = require('phoenix');
const chalk = require('chalk');

class WebSocketClient {
  constructor(wsUrl, token, options = {}) {
    this.wsUrl = wsUrl;
    this.token = token;
    this.options = {
      timeout: 10000,
      heartbeatIntervalMs: 30000,
      rejoinAfterMs: (tries) => [1000, 2000, 5000][tries - 1] || 10000,
      reconnectAfterMs: (tries) => [1000, 2000, 5000][tries - 1] || 10000,
      ...options
    };
    
    this.socket = null;
    this.channel = null;
    this.connected = false;
    this.callbacks = {
      connect: [],
      disconnect: [],
      error: [],
      message: []
    };
  }

  /**
   * Connect to WebSocket
   */
  async connect() {
    console.log(chalk.blue('🔌 Connecting to WebSocket...'));
    
    return new Promise((resolve, reject) => {
      try {
        this.socket = new Socket(this.wsUrl, {
          params: { token: this.token },
          timeout: this.options.timeout,
          heartbeatIntervalMs: this.options.heartbeatIntervalMs,
          rejoinAfterMs: this.options.rejoinAfterMs,
          reconnectAfterMs: this.options.reconnectAfterMs
        });

        // Set up socket event handlers
        this.socket.onOpen(() => {
          console.log(chalk.green('✅ WebSocket connected'));
          this.connected = true;
          this._trigger('connect');
          resolve();
        });

        this.socket.onClose(() => {
          console.log(chalk.yellow('⚠️  WebSocket disconnected'));
          this.connected = false;
          this._trigger('disconnect');
        });

        this.socket.onError((error) => {
          console.error(chalk.red('❌ WebSocket error:', error));
          this._trigger('error', error);
          if (!this.connected) {
            reject(new Error(`WebSocket connection failed: ${error}`));
          }
        });

        // Connect the socket
        this.socket.connect();

      } catch (error) {
        console.error(chalk.red('❌ Failed to create WebSocket connection:', error));
        reject(error);
      }
    });
  }

  /**
   * Join a location channel
   */
  async joinLocationChannel(sessionId) {
    if (!this.socket || !this.connected) {
      throw new Error('WebSocket not connected');
    }

    console.log(chalk.blue(`📡 Joining location channel: location:${sessionId}`));

    return new Promise((resolve, reject) => {
      this.channel = this.socket.channel(`location:${sessionId}`, {});

      // Set up channel event handlers
      this.channel.on('initial_participants', (payload) => {
        console.log(chalk.gray(`👥 Initial participants: ${payload.participants.length}`));
        this._trigger('message', { type: 'initial_participants', data: payload });
      });

      this.channel.on('participant_joined', (payload) => {
        console.log(chalk.green(`👤 Participant joined: ${payload.display_name}`));
        this._trigger('message', { type: 'participant_joined', data: payload });
      });

      this.channel.on('participant_left', (payload) => {
        console.log(chalk.yellow(`👋 Participant left: ${payload.display_name}`));
        this._trigger('message', { type: 'participant_left', data: payload });
      });

      this.channel.on('location_update', (payload) => {
        console.log(chalk.gray(`📍 Location update from ${payload.data.user_id}`));
        this._trigger('message', { type: 'location_update', data: payload });
      });

      this.channel.on('session_ended', (payload) => {
        console.log(chalk.red('🔚 Session ended'));
        this._trigger('message', { type: 'session_ended', data: payload });
      });

      // Join the channel
      this.channel.join()
        .receive('ok', (response) => {
          console.log(chalk.green(`✅ Joined location channel: ${response.session_id}`));
          resolve(response);
        })
        .receive('error', (error) => {
          console.error(chalk.red('❌ Failed to join location channel:', error));
          reject(new Error(`Failed to join channel: ${error.reason || 'unknown error'}`));
        })
        .receive('timeout', () => {
          console.error(chalk.red('❌ Join channel timeout'));
          reject(new Error('Channel join timeout'));
        });
    });
  }

  /**
   * Send location update
   */
  async sendLocationUpdate(location) {
    if (!this.channel) {
      throw new Error('No active channel');
    }

    const payload = {
      lat: location.lat,
      lng: location.lng,
      accuracy: location.accuracy || 10,
      timestamp: location.timestamp || new Date().toISOString()
    };

    console.log(chalk.gray(`📤 Sending location: ${payload.lat.toFixed(6)}, ${payload.lng.toFixed(6)}`));

    return new Promise((resolve, reject) => {
      this.channel.push('location_update', payload)
        .receive('ok', (response) => {
          resolve(response);
        })
        .receive('error', (error) => {
          console.error(chalk.red('❌ Failed to send location update:', error));
          reject(new Error(`Location update failed: ${error.reason || 'unknown error'}`));
        })
        .receive('timeout', () => {
          console.error(chalk.red('❌ Location update timeout'));
          reject(new Error('Location update timeout'));
        });
    });
  }

  /**
   * Send ping to keep connection alive
   */
  async ping() {
    if (!this.channel) {
      throw new Error('No active channel');
    }

    return new Promise((resolve, reject) => {
      this.channel.push('ping', {})
        .receive('ok', (response) => {
          console.log(chalk.gray('🏓 Pong received'));
          resolve(response);
        })
        .receive('error', (error) => {
          console.error(chalk.red('❌ Ping failed:', error));
          reject(error);
        })
        .receive('timeout', () => {
          console.error(chalk.red('❌ Ping timeout'));
          reject(new Error('Ping timeout'));
        });
    });
  }

  /**
   * Start automatic ping/pong
   */
  startHeartbeat(interval = 30000) {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }

    this.heartbeatInterval = setInterval(async () => {
      if (this.connected && this.channel) {
        try {
          await this.ping();
        } catch (error) {
          console.warn(chalk.yellow('⚠️  Heartbeat ping failed:', error.message));
        }
      }
    }, interval);

    console.log(chalk.gray(`💗 Heartbeat started (${interval/1000}s interval)`));
  }

  /**
   * Stop automatic ping/pong
   */
  stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
      console.log(chalk.gray('💔 Heartbeat stopped'));
    }
  }

  /**
   * Leave the current channel
   */
  async leaveChannel() {
    if (!this.channel) {
      return;
    }

    console.log(chalk.blue('👋 Leaving channel...'));

    return new Promise((resolve) => {
      this.channel.leave()
        .receive('ok', () => {
          console.log(chalk.green('✅ Left channel successfully'));
          this.channel = null;
          resolve();
        })
        .receive('error', (error) => {
          console.warn(chalk.yellow('⚠️  Error leaving channel:', error));
          this.channel = null;
          resolve();
        })
        .receive('timeout', () => {
          console.warn(chalk.yellow('⚠️  Leave channel timeout'));
          this.channel = null;
          resolve();
        });
    });
  }

  /**
   * Disconnect from WebSocket
   */
  async disconnect() {
    console.log(chalk.blue('🔌 Disconnecting from WebSocket...'));

    this.stopHeartbeat();

    if (this.channel) {
      await this.leaveChannel();
    }

    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }

    this.connected = false;
    console.log(chalk.green('✅ WebSocket disconnected'));
  }

  /**
   * Event listener management
   */
  on(event, callback) {
    if (this.callbacks[event]) {
      this.callbacks[event].push(callback);
    }
  }

  off(event, callback) {
    if (this.callbacks[event]) {
      const index = this.callbacks[event].indexOf(callback);
      if (index > -1) {
        this.callbacks[event].splice(index, 1);
      }
    }
  }

  _trigger(event, data = null) {
    if (this.callbacks[event]) {
      this.callbacks[event].forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error(chalk.red(`❌ Event callback error for ${event}:`, error));
        }
      });
    }
  }

  /**
   * Get connection status
   */
  isConnected() {
    return this.connected && this.socket && this.socket.isConnected();
  }

  /**
   * Get channel status
   */
  hasActiveChannel() {
    return this.channel && this.channel.canPush();
  }

  /**
   * Utility method to create and connect WebSocket client
   */
  static async create(wsUrl, token, sessionId, options = {}) {
    const client = new WebSocketClient(wsUrl, token, options);
    
    try {
      await client.connect();
      await client.joinLocationChannel(sessionId);
      client.startHeartbeat();
      
      return client;
    } catch (error) {
      await client.disconnect();
      throw error;
    }
  }
}

module.exports = WebSocketClient;