#!/bin/bash

# Integration test runner for MCP server testing
# Runs tests that require MCP servers and external dependencies

echo "🔧 Running integration tests with MCP servers..."

# Run integration tests with appropriate timeouts
dart test \
  --tags "mcp || integration" \
  --exclude-tags "slow" \
  --concurrency 2 \
  --timeout 30s \
  --reporter expanded \
  test/mcp/ test/integration/ test/unit/*mcp*_test.dart

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "✅ Integration tests completed successfully"
else
    echo "❌ Integration tests failed"
fi

exit $exit_code