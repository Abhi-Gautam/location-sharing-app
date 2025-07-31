/**
 * Visual Recorder - Handle screenshots and video recording during tests
 * 
 * Provides utilities for:
 * - Taking screenshots at specific intervals
 * - Recording videos of browser sessions
 * - Organizing visual assets
 * - Generating comparison images
 */

const puppeteer = require('puppeteer');
const chalk = require('chalk');
const fs = require('fs').promises;
const path = require('path');

class VisualRecorder {
  constructor(outputDir, options = {}) {
    this.outputDir = outputDir;
    this.options = {
      screenshotQuality: 80,
      videoEnabled: false, // Puppeteer doesn't support video recording directly
      fullPage: false,
      format: 'png',
      ...options
    };
    
    this.recordings = new Map(); // Track active recordings per page
    this.screenshotCount = 0;
  }

  /**
   * Initialize recorder and create directories
   */
  async initialize() {
    console.log(chalk.blue('📹 Initializing Visual Recorder'));
    
    // Create output directories
    await fs.mkdir(path.join(this.outputDir, 'screenshots'), { recursive: true });
    await fs.mkdir(path.join(this.outputDir, 'videos'), { recursive: true });
    await fs.mkdir(path.join(this.outputDir, 'comparisons'), { recursive: true });
    
    console.log(chalk.green(`✅ Visual recorder initialized: ${this.outputDir}`));
  }

  /**
   * Take a screenshot of a page
   */
  async takeScreenshot(page, filename, options = {}) {
    const {
      quality = this.options.screenshotQuality,
      fullPage = this.options.fullPage,
      format = this.options.format,
      clip = null,
      retries = 3
    } = options;

    const filepath = path.join(this.outputDir, 'screenshots', filename);
    
    console.log(chalk.gray(`📸 Taking screenshot: ${filename}`));

    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        const screenshotOptions = {
          path: filepath,
          quality: format === 'jpeg' ? quality : undefined,
          fullPage,
          type: format,
          clip
        };

        await page.screenshot(screenshotOptions);
        
        this.screenshotCount++;
        console.log(chalk.green(`✅ Screenshot saved: ${filename}`));
        
        return {
          filepath,
          filename,
          success: true,
          timestamp: new Date().toISOString()
        };
        
      } catch (error) {
        console.warn(chalk.yellow(`⚠️  Screenshot attempt ${attempt}/${retries} failed: ${error.message}`));
        
        if (attempt === retries) {
          console.error(chalk.red(`❌ Failed to take screenshot after ${retries} attempts`));
          return {
            filepath,
            filename,
            success: false,
            error: error.message,
            timestamp: new Date().toISOString()
          };
        }
        
        // Wait before retry
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  }

  /**
   * Take screenshots of multiple pages simultaneously
   */
  async takeScreenshotsOfPages(pages, baseFilename, options = {}) {
    console.log(chalk.blue(`📸 Taking screenshots of ${pages.length} pages...`));
    
    const results = [];
    const promises = pages.map(async (pageInfo, index) => {
      const { page, userId, sessionId, label } = pageInfo;
      const filename = `${baseFilename}-${label || `page-${index + 1}`}.${this.options.format}`;
      
      const result = await this.takeScreenshot(page, filename, options);
      result.userId = userId;
      result.sessionId = sessionId;
      result.index = index;
      
      return result;
    });
    
    const screenshots = await Promise.all(promises);
    results.push(...screenshots);
    
    const successCount = screenshots.filter(s => s.success).length;
    console.log(chalk.green(`✅ Captured ${successCount}/${screenshots.length} screenshots`));
    
    return results;
  }

  /**
   * Start recording a page session (via screenshots at intervals)
   */
  startPageRecording(page, sessionId, userId, options = {}) {
    const {
      interval = 5000, // 5 seconds
      maxScreenshots = 100,
      prefix = 'recording'
    } = options;

    console.log(chalk.blue(`🎬 Starting recording for ${userId} (session: ${sessionId})`));

    const recordingId = `${sessionId}-${userId}`;
    let screenshotIndex = 0;
    
    const recordingData = {
      sessionId,
      userId,
      startTime: Date.now(),
      screenshotIndex: 0,
      screenshots: [],
      active: true
    };

    const captureScreenshot = async () => {
      if (!recordingData.active || screenshotIndex >= maxScreenshots) {
        return;
      }

      const timestamp = Date.now() - recordingData.startTime;
      const filename = `${prefix}-${recordingId}-${String(screenshotIndex).padStart(4, '0')}.${this.options.format}`;
      
      const result = await this.takeScreenshot(page, filename, {
        fullPage: false,
        retries: 1
      });

      if (result.success) {
        recordingData.screenshots.push({
          ...result,
          index: screenshotIndex,
          timestamp
        });
      }

      screenshotIndex++;
      
      // Schedule next screenshot
      if (recordingData.active && screenshotIndex < maxScreenshots) {
        setTimeout(captureScreenshot, interval);
      }
    };

    // Start capturing
    this.recordings.set(recordingId, recordingData);
    setTimeout(captureScreenshot, interval); // Start after first interval

    console.log(chalk.green(`✅ Recording started for ${userId} (${interval/1000}s intervals)`));
    return recordingId;
  }

  /**
   * Stop recording for a specific page
   */
  stopPageRecording(recordingId) {
    const recording = this.recordings.get(recordingId);
    if (!recording) {
      console.warn(chalk.yellow(`⚠️  Recording not found: ${recordingId}`));
      return null;
    }

    recording.active = false;
    recording.endTime = Date.now();
    recording.duration = recording.endTime - recording.startTime;

    console.log(chalk.green(`🎬 Recording stopped for ${recordingId}: ${recording.screenshots.length} screenshots over ${Math.round(recording.duration/1000)}s`));

    return recording;
  }

  /**
   * Stop all active recordings
   */
  stopAllRecordings() {
    console.log(chalk.blue('🛑 Stopping all recordings...'));
    
    const results = [];
    for (const [recordingId, recording] of this.recordings.entries()) {
      if (recording.active) {
        const result = this.stopPageRecording(recordingId);
        if (result) results.push(result);
      }
    }

    console.log(chalk.green(`✅ Stopped ${results.length} recordings`));
    return results;
  }

  /**
   * Create a comparison grid of screenshots
   */
  async createComparisonGrid(screenshots, outputFilename, options = {}) {
    const {
      columns = 2,
      title = 'Screenshot Comparison',
      includeLabels = true
    } = options;

    console.log(chalk.blue(`🖼️  Creating comparison grid: ${outputFilename}`));

    // This would require image processing library like Sharp or Jimp
    // For now, create an HTML comparison
    const htmlContent = this.generateComparisonHTML(screenshots, title, columns, includeLabels);
    const htmlPath = path.join(this.outputDir, 'comparisons', outputFilename.replace(/\.(png|jpg|jpeg)$/, '.html'));
    
    await fs.writeFile(htmlPath, htmlContent);
    
    console.log(chalk.green(`✅ Comparison grid created: ${path.basename(htmlPath)}`));
    return htmlPath;
  }

  /**
   * Generate HTML comparison grid
   */
  generateComparisonHTML(screenshots, title, columns, includeLabels) {
    const rows = Math.ceil(screenshots.length / columns);
    
    let html = `<!DOCTYPE html>
<html>
<head>
    <title>${title}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; text-align: center; }
        .grid { display: grid; grid-template-columns: repeat(${columns}, 1fr); gap: 20px; }
        .screenshot-item { text-align: center; border: 1px solid #ddd; padding: 10px; border-radius: 8px; }
        .screenshot-item img { max-width: 100%; height: auto; border: 1px solid #ccc; }
        .screenshot-label { margin-top: 10px; font-weight: bold; color: #555; }
        .screenshot-meta { margin-top: 5px; font-size: 0.9em; color: #777; }
        .stats { background: #f5f5f5; padding: 15px; border-radius: 8px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>${title}</h1>
    
    <div class="stats">
        <strong>Total Screenshots:</strong> ${screenshots.length}<br>
        <strong>Grid Layout:</strong> ${columns} columns × ${rows} rows<br>
        <strong>Generated:</strong> ${new Date().toLocaleString()}
    </div>
    
    <div class="grid">`;

    for (const screenshot of screenshots) {
      const relativePath = path.relative(
        path.join(this.outputDir, 'comparisons'),
        screenshot.filepath
      );
      
      html += `
        <div class="screenshot-item">
            <img src="${relativePath}" alt="${screenshot.filename}" />
            ${includeLabels ? `
                <div class="screenshot-label">${screenshot.filename}</div>
                <div class="screenshot-meta">
                    ${screenshot.userId ? `User: ${screenshot.userId}<br>` : ''}
                    ${screenshot.sessionId ? `Session: ${screenshot.sessionId}<br>` : ''}
                    ${screenshot.timestamp ? `Time: ${new Date(screenshot.timestamp).toLocaleTimeString()}` : ''}
                </div>
            ` : ''}
        </div>`;
    }

    html += `
    </div>
</body>
</html>`;

    return html;
  }

  /**
   * Create a timelapse from recording screenshots
   */
  async createTimelapse(recordingId, outputFilename) {
    const recording = this.recordings.get(recordingId);
    if (!recording) {
      console.error(chalk.red(`❌ Recording not found: ${recordingId}`));
      return null;
    }

    console.log(chalk.blue(`🎞️  Creating timelapse for ${recordingId}...`));

    // Create HTML timelapse viewer
    const htmlContent = this.generateTimelapseHTML(recording, outputFilename);
    const htmlPath = path.join(this.outputDir, 'videos', outputFilename.replace(/\.(mp4|avi|gif)$/, '.html'));
    
    await fs.writeFile(htmlPath, htmlContent);
    
    console.log(chalk.green(`✅ Timelapse viewer created: ${path.basename(htmlPath)}`));
    return htmlPath;
  }

  /**
   * Generate HTML timelapse viewer
   */
  generateTimelapseHTML(recording, title) {
    const screenshots = recording.screenshots.sort((a, b) => a.index - b.index);
    
    return `<!DOCTYPE html>
<html>
<head>
    <title>Timelapse: ${title}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; text-align: center; }
        h1 { color: #333; }
        .timelapse-container { max-width: 800px; margin: 0 auto; }
        .timelapse-image { max-width: 100%; height: auto; border: 2px solid #ddd; border-radius: 8px; }
        .controls { margin: 20px 0; }
        .controls button { padding: 10px 20px; margin: 0 5px; font-size: 16px; }
        .progress { margin: 10px 0; }
        .progress input { width: 100%; }
        .info { background: #f5f5f5; padding: 15px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Timelapse: ${title}</h1>
    
    <div class="info">
        <strong>User:</strong> ${recording.userId}<br>
        <strong>Session:</strong> ${recording.sessionId}<br>
        <strong>Duration:</strong> ${Math.round(recording.duration/1000)}s<br>
        <strong>Screenshots:</strong> ${screenshots.length}
    </div>
    
    <div class="timelapse-container">
        <img id="timelapseImage" class="timelapse-image" src="" alt="Timelapse frame" />
        
        <div class="controls">
            <button onclick="playPause()">▶️ Play/Pause</button>
            <button onclick="reset()">⏮️ Reset</button>
            <button onclick="changeSpeed(-0.5)">🐌 Slower</button>
            <button onclick="changeSpeed(0.5)">🐰 Faster</button>
        </div>
        
        <div class="progress">
            <input type="range" id="progressSlider" min="0" max="${screenshots.length - 1}" value="0" 
                   oninput="seekTo(this.value)" />
        </div>
        
        <div id="frameInfo">Frame 1 / ${screenshots.length}</div>
    </div>

    <script>
        const screenshots = ${JSON.stringify(screenshots.map(s => ({
          filename: path.relative(path.join(this.outputDir, 'videos'), s.filepath),
          index: s.index,
          timestamp: s.timestamp
        })))};
        
        let currentFrame = 0;
        let playing = false;
        let playInterval = null;
        let speed = 1; // frames per second
        
        function updateFrame() {
            if (screenshots.length === 0) return;
            
            const screenshot = screenshots[currentFrame];
            document.getElementById('timelapseImage').src = screenshot.filename;
            document.getElementById('progressSlider').value = currentFrame;
            document.getElementById('frameInfo').textContent = 
                \`Frame \${currentFrame + 1} / \${screenshots.length} (t+\${Math.round(screenshot.timestamp/1000)}s)\`;
        }
        
        function playPause() {
            playing = !playing;
            
            if (playing) {
                playInterval = setInterval(() => {
                    currentFrame = (currentFrame + 1) % screenshots.length;
                    updateFrame();
                }, 1000 / speed);
            } else {
                clearInterval(playInterval);
            }
        }
        
        function reset() {
            playing = false;
            clearInterval(playInterval);
            currentFrame = 0;
            updateFrame();
        }
        
        function changeSpeed(delta) {
            speed = Math.max(0.1, Math.min(10, speed + delta));
            
            if (playing) {
                clearInterval(playInterval);
                playInterval = setInterval(() => {
                    currentFrame = (currentFrame + 1) % screenshots.length;
                    updateFrame();
                }, 1000 / speed);
            }
        }
        
        function seekTo(frame) {
            currentFrame = parseInt(frame);
            updateFrame();
        }
        
        // Initialize
        updateFrame();
    </script>
</body>
</html>`;
  }

  /**
   * Get recording statistics
   */
  getRecordingStats() {
    const stats = {
      totalScreenshots: this.screenshotCount,
      activeRecordings: 0,
      completedRecordings: 0,
      recordings: []
    };

    for (const [recordingId, recording] of this.recordings.entries()) {
      if (recording.active) {
        stats.activeRecordings++;
      } else {
        stats.completedRecordings++;
      }

      stats.recordings.push({
        id: recordingId,
        userId: recording.userId,
        sessionId: recording.sessionId,
        active: recording.active,
        screenshots: recording.screenshots.length,
        duration: recording.duration || (Date.now() - recording.startTime)
      });
    }

    return stats;
  }

  /**
   * Clean up resources
   */
  async cleanup() {
    console.log(chalk.blue('🧹 Cleaning up visual recorder...'));
    
    // Stop all active recordings
    this.stopAllRecordings();
    
    // Clear recordings map
    this.recordings.clear();
    
    console.log(chalk.green('✅ Visual recorder cleanup complete'));
  }
}

module.exports = VisualRecorder;