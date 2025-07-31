/**
 * Movement Simulator - Generates realistic GPS movement patterns
 * 
 * Features:
 * - Multiple movement pattern types (random walk, routes, stationary)
 * - Realistic speed variations
 * - GPS accuracy simulation
 * - Boundary constraints
 * - Time-based coordinate generation
 */

const chalk = require('chalk');

class MovementSimulator {
  constructor() {
    this.patterns = {
      RANDOM_WALK: 'random_walk',
      ROUTE: 'route', 
      STATIONARY: 'stationary',
      CIRCULAR: 'circular',
      COMMUTE: 'commute'
    };
    
    // San Francisco area bounds (default)
    this.defaultBounds = {
      north: 37.7849,   // North boundary
      south: 37.7649,   // South boundary  
      east: -122.4094,  // East boundary
      west: -122.4294   // West boundary
    };
    
    // Speed presets (mph to m/s conversion)
    this.speedPresets = {
      walking: { min: 0.5, max: 4.0 },      // 0.2-1.8 m/s
      cycling: { min: 8.0, max: 15.0 },     // 3.6-6.7 m/s  
      driving: { min: 15.0, max: 35.0 },    // 6.7-15.6 m/s
      stationary: { min: 0.0, max: 0.1 }    // Nearly stationary
    };
  }

  /**
   * Generate a complete movement pattern for a user
   */
  generateMovementPattern(options = {}) {
    const config = {
      patternType: this.patterns.RANDOM_WALK,
      duration: 300, // 5 minutes
      updateInterval: 2000, // 2 seconds
      bounds: this.defaultBounds,
      speedType: 'walking',
      startLocation: null,
      ...options
    };
    
    console.log(chalk.gray(`🗺️  Generating ${config.patternType} pattern for ${config.duration}s`));
    
    const totalUpdates = Math.floor(config.duration * 1000 / config.updateInterval);
    const locations = [];
    
    // Generate starting location
    let currentLocation = config.startLocation || this.generateRandomLocation(config.bounds);
    
    for (let i = 0; i < totalUpdates; i++) {
      const timestamp = Date.now() + (i * config.updateInterval);
      
      // Generate next location based on pattern type
      currentLocation = this.generateNextLocation(
        currentLocation, 
        config.patternType,
        config.speedType,
        config.updateInterval / 1000, // Convert to seconds
        config.bounds,
        i,
        totalUpdates
      );
      
      locations.push({
        lat: currentLocation.lat,
        lng: currentLocation.lng,
        accuracy: this.generateAccuracy(),
        timestamp: new Date(timestamp).toISOString(),
        speed: currentLocation.speed || 0,
        heading: currentLocation.heading || 0
      });
    }
    
    console.log(chalk.green(`✅ Generated ${locations.length} location points`));
    return locations;
  }

  /**
   * Generate next location based on movement pattern
   */
  generateNextLocation(currentLocation, patternType, speedType, deltaTime, bounds, stepIndex, totalSteps) {
    const speedRange = this.speedPresets[speedType] || this.speedPresets.walking;
    
    switch (patternType) {
      case this.patterns.RANDOM_WALK:
        return this.generateRandomWalkStep(currentLocation, speedRange, deltaTime, bounds);
        
      case this.patterns.ROUTE:
        return this.generateRouteStep(currentLocation, speedRange, deltaTime, bounds, stepIndex, totalSteps);
        
      case this.patterns.STATIONARY:
        return this.generateStationaryStep(currentLocation);
        
      case this.patterns.CIRCULAR:
        return this.generateCircularStep(currentLocation, speedRange, deltaTime, stepIndex, totalSteps);
        
      case this.patterns.COMMUTE:
        return this.generateCommuteStep(currentLocation, speedRange, deltaTime, bounds, stepIndex, totalSteps);
        
      default:
        return this.generateRandomWalkStep(currentLocation, speedRange, deltaTime, bounds);
    }
  }

  /**
   * Random walk movement - unpredictable direction changes
   */
  generateRandomWalkStep(currentLocation, speedRange, deltaTime, bounds) {
    // Random speed within range
    const speed = this.randomBetween(speedRange.min, speedRange.max);
    
    // Random heading (0-360 degrees)
    const heading = Math.random() * 360;
    
    // Convert speed and heading to lat/lng delta
    const distance = speed * deltaTime * 0.00001; // Rough conversion
    const latDelta = distance * Math.cos(heading * Math.PI / 180);
    const lngDelta = distance * Math.sin(heading * Math.PI / 180);
    
    let newLat = currentLocation.lat + latDelta;
    let newLng = currentLocation.lng + lngDelta;
    
    // Keep within bounds
    newLat = this.clampToBounds(newLat, bounds.south, bounds.north);
    newLng = this.clampToBounds(newLng, bounds.west, bounds.east);
    
    return {
      lat: newLat,
      lng: newLng,
      speed,
      heading
    };
  }

  /**
   * Route movement - following a predetermined path
   */
  generateRouteStep(currentLocation, speedRange, deltaTime, bounds, stepIndex, totalSteps) {
    // Create a simple route from southwest to northeast
    const startLat = bounds.south + 0.001;
    const startLng = bounds.west + 0.001;  
    const endLat = bounds.north - 0.001;
    const endLng = bounds.east - 0.001;
    
    const progress = stepIndex / totalSteps;
    const speed = this.randomBetween(speedRange.min, speedRange.max);
    
    // Interpolate along route with some randomness
    const routeLat = startLat + (endLat - startLat) * progress;
    const routeLng = startLng + (endLng - startLng) * progress;
    
    // Add small random deviation to make it more realistic
    const deviation = 0.0001;
    const newLat = routeLat + (Math.random() - 0.5) * deviation;
    const newLng = routeLng + (Math.random() - 0.5) * deviation;
    
    const heading = this.calculateHeading(currentLocation, { lat: newLat, lng: newLng });
    
    return {
      lat: newLat,
      lng: newLng,
      speed,
      heading
    };
  }

  /**
   * Stationary movement - small random movements around a fixed point
   */
  generateStationaryStep(currentLocation) {
    const maxDeviation = 0.0001; // ~10 meters
    
    const latDelta = (Math.random() - 0.5) * maxDeviation;
    const lngDelta = (Math.random() - 0.5) * maxDeviation;
    
    return {
      lat: currentLocation.lat + latDelta,
      lng: currentLocation.lng + lngDelta,
      speed: 0,
      heading: 0
    };
  }

  /**
   * Circular movement - moving in a circular pattern
   */
  generateCircularStep(currentLocation, speedRange, deltaTime, stepIndex, totalSteps) {
    const radius = 0.002; // Radius in degrees (roughly 200m)
    const centerLat = currentLocation.lat || 37.7749;
    const centerLng = currentLocation.lng || -122.4194;
    
    const angleStep = (2 * Math.PI) / totalSteps;
    const currentAngle = angleStep * stepIndex;
    
    const newLat = centerLat + radius * Math.cos(currentAngle);
    const newLng = centerLng + radius * Math.sin(currentAngle);
    
    const speed = this.randomBetween(speedRange.min, speedRange.max);
    const heading = (currentAngle * 180 / Math.PI + 90) % 360;
    
    return {
      lat: newLat,
      lng: newLng,
      speed,
      heading
    };
  }

  /**
   * Commute movement - realistic commuting pattern with stops
   */
  generateCommuteStep(currentLocation, speedRange, deltaTime, bounds, stepIndex, totalSteps) {
    const commutePhases = [
      { phase: 'start', duration: 0.1, speed: 'stationary' },
      { phase: 'travel', duration: 0.8, speed: 'driving' },
      { phase: 'end', duration: 0.1, speed: 'walking' }
    ];
    
    const progress = stepIndex / totalSteps;
    let currentPhase = commutePhases[0];
    let phaseProgress = 0;
    
    // Determine current phase
    let cumulativeDuration = 0;
    for (const phase of commutePhases) {
      if (progress <= cumulativeDuration + phase.duration) {
        currentPhase = phase;
        phaseProgress = (progress - cumulativeDuration) / phase.duration;
        break;
      }
      cumulativeDuration += phase.duration;
    }
    
    // Adjust speed based on phase
    const phaseSpeedRange = this.speedPresets[currentPhase.speed] || speedRange;
    
    if (currentPhase.phase === 'start' || currentPhase.phase === 'end') {
      return this.generateStationaryStep(currentLocation);
    } else {
      return this.generateRouteStep(currentLocation, phaseSpeedRange, deltaTime, bounds, stepIndex, totalSteps);
    }
  }

  /**
   * Generate random location within bounds
   */
  generateRandomLocation(bounds) {
    return {
      lat: this.randomBetween(bounds.south, bounds.north),
      lng: this.randomBetween(bounds.west, bounds.east)
    };
  }

  /**
   * Generate realistic GPS accuracy (in meters)
   */
  generateAccuracy() {
    // Most GPS readings are 1-10m accurate, occasionally up to 100m  
    const accuracyDistribution = [
      { weight: 60, range: [1, 5] },     // 60% chance: 1-5m (very accurate)
      { weight: 30, range: [5, 15] },    // 30% chance: 5-15m (good)  
      { weight: 8, range: [15, 50] },    // 8% chance: 15-50m (poor)
      { weight: 2, range: [50, 100] }    // 2% chance: 50-100m (very poor)
    ];
    
    const random = Math.random() * 100;
    let cumulativeWeight = 0;
    
    for (const dist of accuracyDistribution) {
      cumulativeWeight += dist.weight;
      if (random <= cumulativeWeight) {
        return this.randomBetween(dist.range[0], dist.range[1]);
      }
    }
    
    return 5; // Default to 5m accuracy
  }

  /**
   * Calculate heading between two points
   */
  calculateHeading(from, to) {
    const latDelta = to.lat - from.lat;
    const lngDelta = to.lng - from.lng;
    
    let heading = Math.atan2(lngDelta, latDelta) * 180 / Math.PI;
    if (heading < 0) heading += 360;
    
    return heading;
  }

  /**
   * Utility functions
   */
  randomBetween(min, max) {
    return min + Math.random() * (max - min);
  }

  clampToBounds(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  /**
   * Generate multiple movement patterns for different users
   */
  generateMultiplePatterns(userCount, options = {}) {
    console.log(chalk.blue(`🎯 Generating movement patterns for ${userCount} users`));
    
    const patterns = [];
    const patternTypes = Object.values(this.patterns);
    
    for (let i = 0; i < userCount; i++) {
      // Distribute pattern types evenly
      const patternType = patternTypes[i % patternTypes.length];
      
      // Vary speed types  
      const speedTypes = ['walking', 'cycling', 'driving'];
      const speedType = speedTypes[i % speedTypes.length];
      
      // Generate unique starting location for each user
      const startLocation = this.generateRandomLocation(options.bounds || this.defaultBounds);
      
      const pattern = this.generateMovementPattern({
        ...options,
        patternType,
        speedType,
        startLocation
      });
      
      patterns.push({
        userId: `user-${i + 1}`,
        patternType,
        speedType,
        startLocation,
        pattern
      });
    }
    
    console.log(chalk.green(`✅ Generated ${patterns.length} movement patterns`));
    return patterns;
  }

  /**
   * Create a realistic city bounds for testing
   */
  static createCityBounds(city = 'san_francisco') {
    const cityBounds = {
      san_francisco: {
        north: 37.7849,
        south: 37.7649, 
        east: -122.4094,
        west: -122.4294
      },
      new_york: {
        north: 40.7589,
        south: 40.7389,
        east: -73.9741,
        west: -73.9941  
      },
      london: {
        north: 51.5174,
        south: 51.4974,
        east: -0.1178,
        west: -0.1378
      }
    };
    
    return cityBounds[city] || cityBounds.san_francisco;
  }
}

module.exports = MovementSimulator;