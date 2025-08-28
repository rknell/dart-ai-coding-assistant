#!/bin/bash

# Fast unit test runner for development
# Runs only true unit tests without MCP server dependencies

echo "🏃 Running fast unit tests for development feedback..."

# Run only pure unit tests by directory, excluding MCP-related tests
dart test \
  --concurrency 8 \
  --timeout 5s \
  --reporter compact \
  test/unit/cache_manager._test.dart test/unit/tool_call_justification_test.dart

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "✅ Fast unit tests completed successfully"
else
    echo "❌ Unit tests failed"
fi

exit $exit_code