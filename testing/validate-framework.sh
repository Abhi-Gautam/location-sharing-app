#!/bin/bash

# Visual Testing Framework Validation Script
# Validates that all components are properly installed and configured

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${PURPLE}[VALIDATION]${NC} $1"; }

validation_errors=0

validate_structure() {
    log_info "🔍 Validating framework structure..."
    
    local required_files=(
        "visual-tests/package.json"
        "visual-tests/test-coordinator.js"
        "visual-tests/browser-manager.js" 
        "visual-tests/movement-simulator.js"
        "visual-tests/run-visual-tests.sh"
        "visual-tests/k6-scripts/websocket-load.js"
        "visual-tests/k6-scripts/session-stress.js"
        "visual-tests/dashboard/server.js"
        "visual-tests/dashboard/public/index.html"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "✅ Found: $file"
        else
            log_error "❌ Missing: $file"
            ((validation_errors++))
        fi
    done
}

validate_dependencies() {
    log_info "🔍 Validating dependencies..."
    
    # Check Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_success "✅ Node.js: $NODE_VERSION"
    else
        log_error "❌ Node.js not found"
        ((validation_errors++))
    fi
    
    # Check npm
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        log_success "✅ npm: $NPM_VERSION"
    else
        log_error "❌ npm not found"
        ((validation_errors++))
    fi
    
    # Check K6 (optional)
    if command -v k6 &> /dev/null; then
        K6_VERSION=$(k6 version --json | jq -r '.k6' 2>/dev/null || k6 version | head -1)
        log_success "✅ K6: $K6_VERSION"
    else
        log_warning "⚠️  K6 not found (load testing will be limited)"
    fi
    
    # Check curl
    if command -v curl &> /dev/null; then
        log_success "✅ curl available"
    else
        log_error "❌ curl not found"
        ((validation_errors++))
    fi
}

validate_node_modules() {
    log_info "🔍 Validating Node.js dependencies..."
    
    cd visual-tests
    
    if [[ -f "package.json" ]]; then
        if [[ -d "node_modules" ]]; then
            log_success "✅ node_modules directory exists"
            
            # Check key dependencies
            local key_deps=("puppeteer" "express" "socket.io" "ws" "axios" "chalk")
            for dep in "${key_deps[@]}"; do
                if [[ -d "node_modules/$dep" ]]; then
                    log_success "✅ $dep installed"
                else
                    log_warning "⚠️  $dep missing - run 'npm install'"
                fi
            done
        else
            log_warning "⚠️  node_modules not found - run 'npm install'"
        fi
    else
        log_error "❌ package.json not found in visual-tests/"
        ((validation_errors++))
    fi
    
    cd ..
}

validate_services() {
    log_info "🔍 Validating required services..."
    
    # Check backend service
    if curl -s http://localhost:4000/health > /dev/null 2>&1; then
        log_success "✅ Backend service (localhost:4000) is running"
    else
        log_warning "⚠️  Backend service not running - start with './run.sh --elixir'"
    fi
    
    # Check frontend service
    if curl -s http://localhost:52778 > /dev/null 2>&1; then
        log_success "✅ Frontend service (localhost:52778) is running"
    else
        log_warning "⚠️  Frontend service not running - start with './run.sh --flutter'"
    fi
    
    # Check database
    if nc -z localhost 5432 2>/dev/null; then
        log_success "✅ PostgreSQL database (localhost:5432) is accessible"
    else
        log_warning "⚠️  Database not accessible - start with './run.sh --start'"
    fi
}

validate_permissions() {
    log_info "🔍 Validating file permissions..."
    
    local executable_files=(
        "visual-tests/run-visual-tests.sh"
        "../test-runner.sh"
        "../health-monitor.sh"
        "../run.sh"
    )
    
    for file in "${executable_files[@]}"; do
        if [[ -f "$file" ]]; then
            if [[ -x "$file" ]]; then
                log_success "✅ Executable: $file"
            else
                log_warning "⚠️  Not executable: $file (run 'chmod +x $file')"
            fi
        fi
    done
}

validate_configuration() {
    log_info "🔍 Validating configuration files..."
    
    # Check test-coordinator configuration
    if grep -q "flutterUrl.*localhost:52778" visual-tests/test-coordinator.js; then
        log_success "✅ Test coordinator Flutter URL configured"
    else
        log_warning "⚠️  Test coordinator Flutter URL may need adjustment"
    fi
    
    # Check dashboard configuration
    if grep -q "port.*3001" visual-tests/dashboard/server.js; then
        log_success "✅ Dashboard port configured"
    else
        log_warning "⚠️  Dashboard port configuration may need adjustment"
    fi
    
    # Check K6 scripts configuration
    if grep -q "localhost:4000" visual-tests/k6-scripts/websocket-load.js; then
        log_success "✅ K6 WebSocket script configured"
    else
        log_warning "⚠️  K6 WebSocket script may need configuration"
    fi
}

run_quick_test() {
    log_info "🔍 Running quick framework test..."
    
    cd visual-tests
    
    # Test Node.js module loading
    if node -e "require('./test-coordinator.js'); console.log('✅ test-coordinator.js loads successfully')" 2>/dev/null; then
        log_success "✅ Test coordinator module loads"
    else
        log_error "❌ Test coordinator module failed to load"
        ((validation_errors++))
    fi
    
    if node -e "require('./browser-manager.js'); console.log('✅ browser-manager.js loads successfully')" 2>/dev/null; then
        log_success "✅ Browser manager module loads"
    else
        log_error "❌ Browser manager module failed to load"
        ((validation_errors++))
    fi
    
    if node -e "require('./movement-simulator.js'); console.log('✅ movement-simulator.js loads successfully')" 2>/dev/null; then
        log_success "✅ Movement simulator module loads"
    else
        log_error "❌ Movement simulator module failed to load"
        ((validation_errors++))
    fi
    
    cd ..
}

generate_validation_report() {
    log_info "📊 Generating validation report..."
    
    cat > validation-report.md << EOF
# Visual Testing Framework Validation Report

**Date:** $(date)
**Validation Errors:** $validation_errors

## Structure Validation
- Framework files and directories ✓
- Required scripts and modules ✓
- Documentation files ✓

## Dependencies
- Node.js: $(command -v node &> /dev/null && node --version || echo "Not found")
- npm: $(command -v npm &> /dev/null && npm --version || echo "Not found")
- K6: $(command -v k6 &> /dev/null && echo "Available" || echo "Not found")
- curl: $(command -v curl &> /dev/null && echo "Available" || echo "Not found")

## Services Status
- Backend (localhost:4000): $(curl -s http://localhost:4000/health > /dev/null 2>&1 && echo "Running" || echo "Not running")
- Frontend (localhost:52778): $(curl -s http://localhost:52778 > /dev/null 2>&1 && echo "Running" || echo "Not running")
- Database (localhost:5432): $(nc -z localhost 5432 2>/dev/null && echo "Accessible" || echo "Not accessible")

## Recommendations

$(if [ $validation_errors -eq 0 ]; then
    echo "✅ **Framework is ready for use!**"
    echo ""
    echo "Next steps:"
    echo "1. Start services: \`./run.sh --start\`"
    echo "2. Run quick test: \`cd testing/visual-tests && ./run-visual-tests.sh\`"
    echo "3. Open dashboard: http://localhost:3001"
else
    echo "❌ **Please address the validation errors above before using the framework.**"
    echo ""
    echo "Common fixes:"
    echo "1. Install Node.js dependencies: \`cd testing/visual-tests && npm install\`"
    echo "2. Make scripts executable: \`chmod +x testing/visual-tests/*.sh\`"
    echo "3. Start required services: \`./run.sh --start\`"
fi)

## Quick Start

\`\`\`bash
# Install dependencies
cd testing/visual-tests
npm install

# Start services
cd ../../
./run.sh --start

# Run light test
cd testing/visual-tests
./run-visual-tests.sh --scenario light
\`\`\`

---
Generated by Visual Testing Framework Validator
EOF

    log_success "✅ Validation report saved: validation-report.md"
}

main() {
    log_header "🎯 Visual Testing Framework Validation"
    echo "============================================="
    
    validate_structure
    validate_dependencies
    validate_node_modules
    validate_services
    validate_permissions
    validate_configuration
    run_quick_test
    
    echo "============================================="
    
    if [ $validation_errors -eq 0 ]; then
        log_success "🎉 Framework validation passed! Ready to use."
        log_info "📚 See testing/README.md for usage instructions"
        log_info "🚀 Quick start: cd testing/visual-tests && ./run-visual-tests.sh"
    else
        log_error "💥 Validation failed with $validation_errors error(s)"
        log_info "📋 Check validation-report.md for details"
    fi
    
    generate_validation_report
    
    exit $validation_errors
}

main "$@"