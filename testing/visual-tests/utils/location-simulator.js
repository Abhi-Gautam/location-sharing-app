/**
 * Location Simulator - Generate realistic movement patterns for testing
 * 
 * Creates various movement patterns including:
 * - Random walk
 * - Route following
 * - Circular movement
 * - Stationary behavior
 * - Realistic daily patterns
 */

const chalk = require('chalk');

class LocationSimulator {
  constructor(config = {}) {
    this.config = {
      updateInterval: 2000, // 2 seconds
      earthRadius: 6371000, // Earth radius in meters
      ...config
    };
    
    // Default bounds (San Francisco)
    this.defaultBounds = {
      north: 37.7849,
      south: 37.7649,
      east: -122.3894,
      west: -122.4494
    };
  }

  /**
   * Generate movement pattern for a user
   */
  generateMovementPattern(options = {}) {
    const {
      patternType = 'random',
      duration = 300, // 5 minutes
      updateInterval = this.config.updateInterval,
      bounds = this.defaultBounds,
      speedType = 'walking',
      startLocation = null
    } = options;

    console.log(chalk.blue(`🗺️  Generating ${patternType} movement pattern (${duration}s)`));

    const totalUpdates = Math.floor(duration * 1000 / updateInterval);
    const locations = [];

    // Get starting location
    const start = startLocation || this.getRandomLocationInBounds(bounds);
    locations.push({
      lat: start.lat,
      lng: start.lng,
      accuracy: this.getRandomAccuracy(),
      timestamp: new Date().toISOString(),
      speed: 0
    });

    // Generate movement based on pattern type
    switch (patternType) {
      case 'random':
      case 'random_walk':
        this.generateRandomWalk(locations, totalUpdates, bounds, speedType);
        break;
        
      case 'route':
        this.generateRouteMovement(locations, totalUpdates, bounds, speedType);
        break;
        
      case 'circular':
        this.generateCircularMovement(locations, totalUpdates, bounds, speedType);
        break;
        
      case 'stationary':
        this.generateStationaryMovement(locations, totalUpdates, bounds);
        break;
        
      case 'commute':
        this.generateCommutePattern(locations, totalUpdates, bounds, speedType);
        break;
        
      case 'mixed':
        this.generateMixedPattern(locations, totalUpdates, bounds);
        break;
        
      case 'realistic':
        this.generateRealisticPattern(locations, totalUpdates, bounds);
        break;
        
      default:
        console.warn(chalk.yellow(`⚠️  Unknown pattern: ${patternType}, using random walk`));
        this.generateRandomWalk(locations, totalUpdates, bounds, speedType);
    }

    console.log(chalk.green(`✅ Generated ${locations.length} location points`));
    return locations;
  }

  /**
   * Random walk movement pattern
   */
  generateRandomWalk(locations, totalUpdates, bounds, speedType) {
    const speed = this.getSpeedMps(speedType);
    const updateIntervalSec = this.config.updateInterval / 1000;
    
    for (let i = 1; i < totalUpdates; i++) {
      const prevLocation = locations[i - 1];
      
      // Random direction and distance
      const bearing = Math.random() * 360;
      const distance = speed * updateIntervalSec * (0.5 + Math.random() * 0.5); // Vary speed
      
      const newLocation = this.moveFromLocation(prevLocation, bearing, distance);
      
      // Keep within bounds
      const boundedLocation = this.constrainToBounds(newLocation, bounds);
      
      locations.push({
        lat: boundedLocation.lat,
        lng: boundedLocation.lng,
        accuracy: this.getRandomAccuracy(),
        timestamp: new Date(Date.now() + i * this.config.updateInterval).toISOString(),
        speed: this.calculateSpeed(prevLocation, boundedLocation, updateIntervalSec)
      });
    }
  }

  /**
   * Route following movement pattern
   */
  generateRouteMovement(locations, totalUpdates, bounds, speedType) {
    const speed = this.getSpeedMps(speedType);
    const updateIntervalSec = this.config.updateInterval / 1000;
    
    // Generate a route with waypoints
    const waypoints = this.generateWaypoints(bounds, 5);
    let currentWaypointIndex = 0;
    let targetWaypoint = waypoints[currentWaypointIndex];
    
    for (let i = 1; i < totalUpdates; i++) {
      const prevLocation = locations[i - 1];
      
      // Calculate bearing and distance to target waypoint
      const bearing = this.calculateBearing(prevLocation, targetWaypoint);
      const distanceToTarget = this.calculateDistance(prevLocation, targetWaypoint);
      
      const maxDistance = speed * updateIntervalSec;
      
      let newLocation;
      if (distanceToTarget <= maxDistance) {
        // Reached waypoint, move to next
        newLocation = targetWaypoint;
        currentWaypointIndex = (currentWaypointIndex + 1) % waypoints.length;
        targetWaypoint = waypoints[currentWaypointIndex];
      } else {
        // Move toward waypoint
        newLocation = this.moveFromLocation(prevLocation, bearing, maxDistance);
      }
      
      locations.push({
        lat: newLocation.lat,
        lng: newLocation.lng,
        accuracy: this.getRandomAccuracy(),
        timestamp: new Date(Date.now() + i * this.config.updateInterval).toISOString(),
        speed: this.calculateSpeed(prevLocation, newLocation, updateIntervalSec)
      });
    }
  }

  /**
   * Circular movement pattern
   */
  generateCircularMovement(locations, totalUpdates, bounds, speedType) {
    const speed = this.getSpeedMps(speedType);
    const updateIntervalSec = this.config.updateInterval / 1000;
    
    // Calculate circle parameters
    const center = {
      lat: (bounds.north + bounds.south) / 2,
      lng: (bounds.east + bounds.west) / 2
    };
    
    const radius = Math.min(
      this.calculateDistance({ lat: bounds.north, lng: center.lng }, center),
      this.calculateDistance({ lat: center.lat, lng: bounds.east }, center)
    ) * 0.3; // 30% of available space
    
    const circumference = 2 * Math.PI * radius;
    const angleIncrement = (speed * updateIntervalSec / circumference) * 360;
    
    for (let i = 1; i < totalUpdates; i++) {
      const angle = ((i - 1) * angleIncrement) % 360;
      const newLocation = this.moveFromLocation(center, angle, radius);
      
      locations.push({
        lat: newLocation.lat,
        lng: newLocation.lng,
        accuracy: this.getRandomAccuracy(),
        timestamp: new Date(Date.now() + i * this.config.updateInterval).toISOString(),
        speed: this.calculateSpeed(locations[i - 1], newLocation, updateIntervalSec)
      });
    }
  }

  /**
   * Stationary movement pattern (minimal movement)
   */
  generateStationaryMovement(locations, totalUpdates, bounds) {
    const baseLocation = locations[0];
    
    for (let i = 1; i < totalUpdates; i++) {
      // Very small random movement to simulate GPS noise
      const noiseLat = (Math.random() - 0.5) * 0.00001; // ~1 meter
      const noiseLng = (Math.random() - 0.5) * 0.00001;
      
      locations.push({
        lat: baseLocation.lat + noiseLat,
        lng: baseLocation.lng + noiseLng,
        accuracy: this.getRandomAccuracy(),
        timestamp: new Date(Date.now() + i * this.config.updateInterval).toISOString(),
        speed: 0
      });
    }
  }

  /**
   * Commute pattern (home -> work -> home)
   */
  generateCommutePattern(locations, totalUpdates, bounds, speedType) {
    const home = locations[0];
    const work = this.getRandomLocationInBounds(bounds);
    
    const halfDuration = Math.floor(totalUpdates / 2);
    
    // First half: home to work
    const toWorkLocations = [];
    toWorkLocations.push(home);
    this.generateDirectMovement(toWorkLocations, halfDuration, home, work, speedType);
    
    // Second half: work to home
    const toHomeLocations = [];
    toHomeLocations.push(work);
    this.generateDirectMovement(toHomeLocations, totalUpdates - halfDuration, work, home, speedType);
    
    // Combine locations
    locations.push(...toWorkLocations.slice(1));
    locations.push(...toHomeLocations.slice(1));
  }

  /**
   * Mixed pattern (combination of different movements)
   */
  generateMixedPattern(locations, totalUpdates, bounds) {
    const patterns = ['walking', 'stationary', 'driving'];
    const segmentSize = Math.floor(totalUpdates / patterns.length);
    
    let currentIndex = 0;
    
    for (let p = 0; p < patterns.length; p++) {
      const patternType = patterns[p] === 'driving' ? 'route' : 'random_walk';
      const speedType = patterns[p];
      const segmentLocations = [locations[currentIndex]];
      
      const segmentEnd = p === patterns.length - 1 ? totalUpdates : currentIndex + segmentSize;
      const segmentLength = segmentEnd - currentIndex;
      
      if (speedType === 'stationary') {
        this.generateStationaryMovement(segmentLocations, segmentLength, bounds);
      } else {
        this.generateRandomWalk(segmentLocations, segmentLength, bounds, speedType);
      }
      
      locations.push(...segmentLocations.slice(1));
      currentIndex += segmentLength - 1;
    }
  }

  /**
   * Realistic daily pattern
   */
  generateRealisticPattern(locations, totalUpdates, bounds) {
    // Simulate a realistic day: stationary -> walking -> driving -> stationary
    const phases = [
      { type: 'stationary', duration: 0.2, speed: 'stationary' },
      { type: 'random_walk', duration: 0.3, speed: 'walking' },
      { type: 'route', duration: 0.3, speed: 'driving' },
      { type: 'stationary', duration: 0.2, speed: 'stationary' }
    ];
    
    let currentIndex = 0;
    
    for (const phase of phases) {
      const segmentSize = Math.floor(totalUpdates * phase.duration);
      const segmentLocations = [locations[currentIndex]];
      
      switch (phase.type) {
        case 'stationary':
          this.generateStationaryMovement(segmentLocations, segmentSize, bounds);
          break;
        case 'random_walk':
          this.generateRandomWalk(segmentLocations, segmentSize, bounds, phase.speed);
          break;
        case 'route':
          this.generateRouteMovement(segmentLocations, segmentSize, bounds, phase.speed);
          break;
      }
      
      locations.push(...segmentLocations.slice(1));
      currentIndex += segmentSize - 1;
    }
  }

  // Utility methods

  getSpeedMps(speedType) {
    const speeds = {
      stationary: 0,
      walking: 1.4,    // 5 km/h
      running: 3.3,    // 12 km/h
      cycling: 5.6,    // 20 km/h
      driving: 13.9,   // 50 km/h
      highway: 27.8    // 100 km/h
    };
    
    return speeds[speedType] || speeds.walking;
  }

  getRandomAccuracy() {
    // GPS accuracy between 3-15 meters
    return Math.floor(3 + Math.random() * 12);
  }

  getRandomLocationInBounds(bounds) {
    return {
      lat: bounds.south + Math.random() * (bounds.north - bounds.south),
      lng: bounds.west + Math.random() * (bounds.east - bounds.west)
    };
  }

  generateWaypoints(bounds, count) {
    const waypoints = [];
    for (let i = 0; i < count; i++) {
      waypoints.push(this.getRandomLocationInBounds(bounds));
    }
    return waypoints;
  }

  calculateDistance(point1, point2) {
    const lat1Rad = point1.lat * Math.PI / 180;
    const lat2Rad = point2.lat * Math.PI / 180;
    const deltaLat = (point2.lat - point1.lat) * Math.PI / 180;
    const deltaLng = (point2.lng - point1.lng) * Math.PI / 180;

    const a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
              Math.cos(lat1Rad) * Math.cos(lat2Rad) *
              Math.sin(deltaLng / 2) * Math.sin(deltaLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return this.config.earthRadius * c; // Distance in meters
  }

  calculateBearing(point1, point2) {
    const lat1Rad = point1.lat * Math.PI / 180;
    const lat2Rad = point2.lat * Math.PI / 180;
    const deltaLng = (point2.lng - point1.lng) * Math.PI / 180;

    const x = Math.sin(deltaLng) * Math.cos(lat2Rad);
    const y = Math.cos(lat1Rad) * Math.sin(lat2Rad) -
              Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(deltaLng);

    const bearing = Math.atan2(x, y) * 180 / Math.PI;
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  moveFromLocation(location, bearing, distance) {
    const bearingRad = bearing * Math.PI / 180;
    const lat1Rad = location.lat * Math.PI / 180;
    const lng1Rad = location.lng * Math.PI / 180;

    const lat2Rad = Math.asin(
      Math.sin(lat1Rad) * Math.cos(distance / this.config.earthRadius) +
      Math.cos(lat1Rad) * Math.sin(distance / this.config.earthRadius) * Math.cos(bearingRad)
    );

    const lng2Rad = lng1Rad + Math.atan2(
      Math.sin(bearingRad) * Math.sin(distance / this.config.earthRadius) * Math.cos(lat1Rad),
      Math.cos(distance / this.config.earthRadius) - Math.sin(lat1Rad) * Math.sin(lat2Rad)
    );

    return {
      lat: lat2Rad * 180 / Math.PI,
      lng: lng2Rad * 180 / Math.PI
    };
  }

  constrainToBounds(location, bounds) {
    return {
      lat: Math.max(bounds.south, Math.min(bounds.north, location.lat)),
      lng: Math.max(bounds.west, Math.min(bounds.east, location.lng))
    };
  }

  calculateSpeed(point1, point2, timeIntervalSec) {
    const distance = this.calculateDistance(point1, point2);
    return distance / timeIntervalSec; // Speed in m/s
  }

  generateDirectMovement(locations, totalUpdates, start, end, speedType) {
    const speed = this.getSpeedMps(speedType);
    const updateIntervalSec = this.config.updateInterval / 1000;
    const totalDistance = this.calculateDistance(start, end);
    const bearing = this.calculateBearing(start, end);
    const distancePerUpdate = speed * updateIntervalSec;

    for (let i = 1; i < totalUpdates; i++) {
      const progress = Math.min(1, (i * distancePerUpdate) / totalDistance);
      const currentDistance = progress * totalDistance;
      
      const newLocation = this.moveFromLocation(start, bearing, currentDistance);
      
      locations.push({
        lat: newLocation.lat,
        lng: newLocation.lng,
        accuracy: this.getRandomAccuracy(),
        timestamp: new Date(Date.now() + i * this.config.updateInterval).toISOString(),
        speed: this.calculateSpeed(locations[i - 1], newLocation, updateIntervalSec)
      });
    }
  }
}

module.exports = LocationSimulator;