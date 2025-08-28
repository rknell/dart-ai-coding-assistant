#!/bin/bash

# Comprehensive test runner
# Runs all test categories in sequence with appropriate reporting

echo "🧪 Running comprehensive test suite..."

# Track overall success
overall_success=true

echo ""
echo "📋 1/4 - Fast Unit Tests"
echo "=========================="
./scripts/test-unit.sh
if [ $? -ne 0 ]; then
    overall_success=false
fi

echo ""
echo "🔧 2/4 - Integration Tests"  
echo "=========================="
./scripts/test-integration.sh
if [ $? -ne 0 ]; then
    overall_success=false
fi

echo ""
echo "🐌 3/4 - Slow Integration Tests"
echo "==============================="
dart test \
  --tags "slow" \
  --concurrency 1 \
  --timeout 60s \
  --reporter expanded \
  test/slow_integration/

if [ $? -ne 0 ]; then
    overall_success=false
fi

echo ""
echo "📊 4/4 - Coverage Report"
echo "======================="
dart test \
  --coverage=coverage \
  --exclude-tags "slow" \
  test/

if [ $? -ne 0 ]; then
    overall_success=false
fi

echo ""
echo "📋 Test Suite Summary"
echo "===================="

if [ "$overall_success" = true ]; then
    echo "✅ All test categories completed successfully"
    exit 0
else
    echo "❌ Some test categories failed"
    exit 1
fi