/**
 * Report Generator - Create comprehensive HTML reports for visual tests
 * 
 * Generates detailed reports with:
 * - Test summary and configuration
 * - Performance metrics and charts
 * - Screenshot galleries
 * - Error analysis
 * - Interactive visualizations
 */

const chalk = require('chalk');
const fs = require('fs').promises;
const path = require('path');

class ReportGenerator {
  constructor(outputDir, testData) {
    this.outputDir = outputDir;
    this.testData = testData;
    this.reportPath = path.join(outputDir, 'report.html');
  }

  /**
   * Generate comprehensive HTML report
   */
  async generateReport() {
    console.log(chalk.blue('📊 Generating comprehensive test report...'));

    try {
      const reportHTML = await this.buildReportHTML();
      await fs.writeFile(this.reportPath, reportHTML);
      
      console.log(chalk.green(`✅ Report generated: ${this.reportPath}`));
      return this.reportPath;
      
    } catch (error) {
      console.error(chalk.red(`❌ Failed to generate report: ${error.message}`));
      throw error;
    }
  }

  /**
   * Build complete HTML report
   */
  async buildReportHTML() {
    const reportData = await this.collectReportData();
    
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Visual Test Report - ${reportData.scenario.name}</title>
    ${this.getReportCSS()}
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <div class="container">
        ${this.generateHeader(reportData)}
        ${this.generateSummarySection(reportData)}
        ${this.generateConfigurationSection(reportData)}
        ${this.generatePerformanceSection(reportData)}
        ${this.generateScreenshotsSection(reportData)}
        ${this.generateErrorsSection(reportData)}
        ${this.generateTimelineSection(reportData)}
        ${this.generateFooter(reportData)}
    </div>
    
    ${this.getReportJavaScript(reportData)}
</body>
</html>`;
  }

  /**
   * Collect all report data
   */
  async collectReportData() {
    const screenshots = await this.collectScreenshots();
    const metrics = this.collectMetrics();
    
    return {
      testId: this.testData.testId || `test-${Date.now()}`,
      scenario: this.testData.scenario || { name: 'Unknown Scenario' },
      config: this.testData.config || {},
      execution: this.testData.execution || {
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        duration: 0
      },
      results: this.testData.results || {},
      sessions: this.testData.sessions || [],
      participants: this.testData.participants || [],
      screenshots,
      metrics,
      errors: this.testData.errors || []
    };
  }

  /**
   * Collect screenshot information
   */
  async collectScreenshots() {
    try {
      const screenshotsDir = path.join(this.outputDir, 'screenshots');
      const files = await fs.readdir(screenshotsDir);
      
      const screenshots = [];
      for (const file of files) {
        if (file.match(/\.(png|jpg|jpeg)$/i)) {
          const filepath = path.join(screenshotsDir, file);
          const stat = await fs.stat(filepath);
          
          screenshots.push({
            filename: file,
            path: `screenshots/${file}`,
            size: stat.size,
            timestamp: stat.mtime,
            // Parse filename for metadata
            ...this.parseScreenshotFilename(file)
          });
        }
      }
      
      return screenshots.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
      
    } catch (error) {
      console.warn(chalk.yellow(`⚠️  Could not collect screenshots: ${error.message}`));
      return [];
    }
  }

  /**
   * Parse screenshot filename for metadata
   */
  parseScreenshotFilename(filename) {
    const metadata = {
      type: 'unknown',
      session: null,
      user: null,
      timestamp: null
    };

    // Basic-scenario-user-1-30s.png
    if (filename.includes('basic')) {
      metadata.type = 'basic';
    } else if (filename.includes('stress')) {
      metadata.type = 'stress';
    } else if (filename.includes('session')) {
      metadata.type = 'multi-session';
    }

    // Extract session number
    const sessionMatch = filename.match(/session-(\d+)/);
    if (sessionMatch) {
      metadata.session = parseInt(sessionMatch[1]);
    }

    // Extract user number
    const userMatch = filename.match(/user-(\d+)/);
    if (userMatch) {
      metadata.user = parseInt(userMatch[1]);
    }

    // Extract timestamp
    const timeMatch = filename.match(/(\d+)s\.png$/);
    if (timeMatch) {
      metadata.timestamp = `${timeMatch[1]}s`;
    }

    return metadata;
  }

  /**
   * Collect performance metrics
   */
  collectMetrics() {
    return {
      sessionCreateTime: this.testData.metrics?.sessionCreateTime || 0,
      userLaunchTimes: this.testData.metrics?.userLaunchTimes || [],
      locationUpdatesSent: this.testData.metrics?.locationUpdatesSent || 0,
      errorCount: this.testData.errors?.length || 0,
      successRate: this.calculateSuccessRate()
    };
  }

  /**
   * Calculate success rate
   */
  calculateSuccessRate() {
    if (!this.testData.config || !this.testData.results) return 100;
    
    const expected = this.testData.config.totalUsers || this.testData.config.usersPerSession || 1;
    const actual = this.testData.results.usersJoined || expected;
    
    return Math.round((actual / expected) * 100);
  }

  /**
   * Generate report CSS
   */
  getReportCSS() {
    return `<style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem;
            border-radius: 12px;
            margin-bottom: 2rem;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }
        
        .header .subtitle {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        
        .section {
            background: white;
            padding: 2rem;
            margin-bottom: 2rem;
            border-radius: 12px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .section h2 {
            color: #333;
            margin-bottom: 1.5rem;
            font-size: 1.5rem;
            border-bottom: 2px solid #667eea;
            padding-bottom: 0.5rem;
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }
        
        .metric-card {
            background: #f8f9fa;
            padding: 1.5rem;
            border-radius: 8px;
            text-align: center;
            border-left: 4px solid #667eea;
        }
        
        .metric-value {
            font-size: 2rem;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 0.5rem;
        }
        
        .metric-label {
            color: #666;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .config-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 1rem;
        }
        
        .config-table th,
        .config-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        
        .config-table th {
            background: #f8f9fa;
            font-weight: 600;
        }
        
        .screenshots-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 1rem;
        }
        
        .screenshot-item {
            background: #f8f9fa;
            border-radius: 8px;
            overflow: hidden;
            border: 1px solid #ddd;
        }
        
        .screenshot-item img {
            width: 100%;
            height: 200px;
            object-fit: cover;
            display: block;
        }
        
        .screenshot-info {
            padding: 1rem;
        }
        
        .screenshot-title {
            font-weight: 600;
            margin-bottom: 0.5rem;
        }
        
        .screenshot-meta {
            font-size: 0.9rem;
            color: #666;
        }
        
        .error-list {
            max-height: 400px;
            overflow-y: auto;
            background: #f8f9fa;
            border-radius: 8px;
            padding: 1rem;
        }
        
        .error-item {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 4px;
            padding: 1rem;
            margin-bottom: 1rem;
        }
        
        .error-item:last-child {
            margin-bottom: 0;
        }
        
        .error-type {
            font-weight: 600;
            color: #856404;
            margin-bottom: 0.5rem;
        }
        
        .error-message {
            color: #666;
            font-size: 0.9rem;
        }
        
        .error-timestamp {
            color: #888;
            font-size: 0.8rem;
            margin-top: 0.5rem;
        }
        
        .timeline {
            position: relative;
            padding-left: 2rem;
        }
        
        .timeline::before {
            content: '';
            position: absolute;
            left: 1rem;
            top: 0;
            bottom: 0;
            width: 2px;
            background: #667eea;
        }
        
        .timeline-item {
            position: relative;
            margin-bottom: 2rem;
            background: #f8f9fa;
            padding: 1rem;
            border-radius: 8px;
            margin-left: 1rem;
        }
        
        .timeline-item::before {
            content: '';
            position: absolute;
            left: -1.5rem;
            top: 1rem;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #667eea;
            border: 3px solid white;
        }
        
        .timeline-time {
            color: #667eea;
            font-weight: 600;
            margin-bottom: 0.5rem;
        }
        
        .chart-container {
            position: relative;
            height: 300px;
            margin: 1rem 0;
        }
        
        .footer {
            text-align: center;
            color: #666;
            padding: 2rem 0;
        }
        
        .status-badge {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .status-success {
            background: #d4edda;
            color: #155724;
        }
        
        .status-warning {
            background: #fff3cd;
            color: #856404;
        }
        
        .status-error {
            background: #f8d7da;
            color: #721c24;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 10px;
            }
            
            .metrics-grid {
                grid-template-columns: 1fr;
            }
            
            .screenshots-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>`;
  }

  /**
   * Generate header section
   */
  generateHeader(data) {
    return `
    <div class="header">
        <h1>${data.scenario.name}</h1>
        <div class="subtitle">Test Report Generated on ${new Date().toLocaleString()}</div>
        <div style="margin-top: 1rem;">
            <span class="status-badge ${this.getStatusClass(data.metrics.successRate)}">
                ${data.metrics.successRate}% Success Rate
            </span>
        </div>
    </div>`;
  }

  /**
   * Generate summary section
   */
  generateSummarySection(data) {
    const duration = data.execution.duration || 0;
    const durationText = duration > 0 ? `${Math.round(duration / 1000)}s` : 'N/A';
    
    return `
    <div class="section">
        <h2>📊 Test Summary</h2>
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-value">${data.results.sessionsCreated || 0}</div>
                <div class="metric-label">Sessions Created</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${data.results.usersJoined || 0}</div>
                <div class="metric-label">Users Joined</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${data.screenshots.length}</div>
                <div class="metric-label">Screenshots</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${durationText}</div>
                <div class="metric-label">Duration</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${data.metrics.locationUpdatesSent}</div>
                <div class="metric-label">Location Updates</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${data.errors.length}</div>
                <div class="metric-label">Errors</div>
            </div>
        </div>
    </div>`;
  }

  /**
   * Generate configuration section
   */
  generateConfigurationSection(data) {
    return `
    <div class="section">
        <h2>⚙️ Test Configuration</h2>
        <table class="config-table">
            <tr>
                <th>Parameter</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Test ID</td>
                <td>${data.testId}</td>
            </tr>
            <tr>
                <td>Scenario</td>
                <td>${data.scenario.name}</td>
            </tr>
            <tr>
                <td>Sessions</td>
                <td>${data.config.sessions || 1}</td>
            </tr>
            <tr>
                <td>Users per Session</td>
                <td>${data.config.usersPerSession || 'N/A'}</td>
            </tr>
            <tr>
                <td>Total Users</td>
                <td>${data.config.totalUsers || data.config.usersPerSession || 'N/A'}</td>
            </tr>
            <tr>
                <td>Duration</td>
                <td>${data.config.duration || 'N/A'}s</td>
            </tr>
            <tr>
                <td>Movement Pattern</td>
                <td>${data.config.movementPattern || 'N/A'}</td>
            </tr>
            <tr>
                <td>Start Time</td>
                <td>${new Date(data.execution.startTime).toLocaleString()}</td>
            </tr>
            <tr>
                <td>End Time</td>
                <td>${new Date(data.execution.endTime).toLocaleString()}</td>
            </tr>
        </table>
    </div>`;
  }

  /**
   * Generate performance section
   */
  generatePerformanceSection(data) {
    const avgLaunchTime = data.metrics.userLaunchTimes.length > 0 
      ? Math.round(data.metrics.userLaunchTimes.reduce((a, b) => a + b, 0) / data.metrics.userLaunchTimes.length)
      : 0;

    return `
    <div class="section">
        <h2>📈 Performance Metrics</h2>
        <div class="chart-container">
            <canvas id="performanceChart"></canvas>
        </div>
        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-value">${avgLaunchTime}ms</div>
                <div class="metric-label">Avg Launch Time</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${data.metrics.sessionCreateTime || 0}ms</div>
                <div class="metric-label">Session Create Time</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">${data.metrics.successRate}%</div>
                <div class="metric-label">Success Rate</div>
            </div>
        </div>
    </div>`;
  }

  /**
   * Generate screenshots section
   */
  generateScreenshotsSection(data) {
    if (data.screenshots.length === 0) {
      return `
      <div class="section">
          <h2>📸 Screenshots</h2>
          <p>No screenshots were captured during this test.</p>
      </div>`;
    }

    const screenshotItems = data.screenshots.map(screenshot => `
      <div class="screenshot-item">
          <img src="${screenshot.path}" alt="${screenshot.filename}" loading="lazy">
          <div class="screenshot-info">
              <div class="screenshot-title">${screenshot.filename}</div>
              <div class="screenshot-meta">
                  ${screenshot.type ? `Type: ${screenshot.type}<br>` : ''}
                  ${screenshot.session ? `Session: ${screenshot.session}<br>` : ''}
                  ${screenshot.user ? `User: ${screenshot.user}<br>` : ''}
                  ${screenshot.timestamp ? `Time: ${screenshot.timestamp}<br>` : ''}
                  Size: ${Math.round(screenshot.size / 1024)}KB
              </div>
          </div>
      </div>
    `).join('');

    return `
    <div class="section">
        <h2>📸 Screenshots (${data.screenshots.length})</h2>
        <div class="screenshots-grid">
            ${screenshotItems}
        </div>
    </div>`;
  }

  /**
   * Generate errors section
   */
  generateErrorsSection(data) {
    if (data.errors.length === 0) {
      return `
      <div class="section">
          <h2>🚨 Errors</h2>
          <p style="color: #28a745;">✅ No errors occurred during this test.</p>
      </div>`;
    }

    const errorItems = data.errors.map(error => `
      <div class="error-item">
          <div class="error-type">${error.type || 'Unknown Error'}</div>
          <div class="error-message">${error.message || error.error || 'No details available'}</div>
          <div class="error-timestamp">${error.timestamp ? new Date(error.timestamp).toLocaleString() : 'Unknown time'}</div>
      </div>
    `).join('');

    return `
    <div class="section">
        <h2>🚨 Errors (${data.errors.length})</h2>
        <div class="error-list">
            ${errorItems}
        </div>
    </div>`;
  }

  /**
   * Generate timeline section
   */
  generateTimelineSection(data) {
    const timeline = [
      { time: '00:00', event: 'Test Started', details: `Scenario: ${data.scenario.name}` },
      { time: '00:05', event: 'Sessions Created', details: `${data.results.sessionsCreated || 0} sessions` },
      { time: '00:30', event: 'Users Joined', details: `${data.results.usersJoined || 0} users joined` },
      { time: '01:00', event: 'Location Simulation Started', details: 'Movement patterns activated' },
      { time: 'END', event: 'Test Completed', details: `Duration: ${Math.round((data.execution.duration || 0) / 1000)}s` }
    ];

    const timelineItems = timeline.map(item => `
      <div class="timeline-item">
          <div class="timeline-time">${item.time}</div>
          <div><strong>${item.event}</strong></div>
          <div style="color: #666; font-size: 0.9rem;">${item.details}</div>
      </div>
    `).join('');

    return `
    <div class="section">
        <h2>⏱️ Test Timeline</h2>
        <div class="timeline">
            ${timelineItems}
        </div>
    </div>`;
  }

  /**
   * Generate footer
   */
  generateFooter(data) {
    return `
    <div class="footer">
        <p>Report generated by Visual Testing Framework</p>
        <p>Test ID: ${data.testId} | Generated: ${new Date().toLocaleString()}</p>
    </div>`;
  }

  /**
   * Generate JavaScript for charts and interactivity
   */
  getReportJavaScript(data) {
    return `
    <script>
        // Performance Chart
        const ctx = document.getElementById('performanceChart').getContext('2d');
        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ['Session Create', 'Avg User Launch', 'Location Updates/s', 'Success Rate'],
                datasets: [{
                    label: 'Performance Metrics',
                    data: [
                        ${data.metrics.sessionCreateTime || 0},
                        ${data.metrics.userLaunchTimes.length > 0 
                          ? Math.round(data.metrics.userLaunchTimes.reduce((a, b) => a + b, 0) / data.metrics.userLaunchTimes.length)
                          : 0},
                        ${Math.round(data.metrics.locationUpdatesSent / Math.max(1, (data.execution.duration || 1000) / 1000))},
                        ${data.metrics.successRate}
                    ],
                    backgroundColor: [
                        'rgba(102, 126, 234, 0.6)',
                        'rgba(118, 75, 162, 0.6)',
                        'rgba(255, 99, 132, 0.6)',
                        'rgba(75, 192, 192, 0.6)'
                    ],
                    borderColor: [
                        'rgba(102, 126, 234, 1)',
                        'rgba(118, 75, 162, 1)',
                        'rgba(255, 99, 132, 1)',
                        'rgba(75, 192, 192, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
        
        // Screenshot lightbox
        document.querySelectorAll('.screenshot-item img').forEach(img => {
            img.addEventListener('click', function() {
                const lightbox = document.createElement('div');
                lightbox.style.cssText = \`
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0,0,0,0.9);
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    z-index: 1000;
                    cursor: pointer;
                \`;
                
                const fullImg = document.createElement('img');
                fullImg.src = this.src;
                fullImg.style.cssText = \`
                    max-width: 90%;
                    max-height: 90%;
                    object-fit: contain;
                \`;
                
                lightbox.appendChild(fullImg);
                document.body.appendChild(lightbox);
                
                lightbox.addEventListener('click', () => {
                    document.body.removeChild(lightbox);
                });
            });
        });
    </script>`;
  }

  /**
   * Get status CSS class based on success rate
   */
  getStatusClass(successRate) {
    if (successRate >= 95) return 'status-success';
    if (successRate >= 80) return 'status-warning';
    return 'status-error';
  }

  /**
   * Static method to generate report
   */
  static async generate(outputDir, testData) {
    const generator = new ReportGenerator(outputDir, testData);
    return await generator.generateReport();
  }
}

module.exports = ReportGenerator;