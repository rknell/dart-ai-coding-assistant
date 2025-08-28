# Test Structure Documentation

## Test Organization

The test suite has been reorganized for better performance and maintainability:

### Fast Tests (< 15 seconds)
- `test/unit/` - Pure unit tests with mocks, no external dependencies
- `test/integration/` - Fast integration tests that complete quickly

### Slow Tests (> 30 seconds) 
- `test/slow_integration/` - MCP server tests, hot reload tests, and other slow operations

## Running Tests

### Quick Development Cycle
```bash
# Run fast tests only (recommended for development)
dart test test/unit/ test/integration/ --timeout=15s
```

### Full Test Suite
```bash
# Run all tests including slow integration tests
dart test --timeout=60s
```

### Specific Test Categories
```bash
# Unit tests only
dart test test/unit/

# Fast integration tests only  
dart test test/integration/

# Slow integration tests only
dart test test/slow_integration/
```

## Current Status

✅ **Fast Tests**: All passing, complete in ~10-15 seconds
✅ **Linter**: Clean with zero issues (`dart analyze`)
✅ **Integration Tests**: Core functionality working properly

⚠️ **Slow Integration Tests**: May have timeout issues due to MCP server startup times

## Test Principles

1. **Unit tests** should be fast (<1s each) and use mocks
2. **Integration tests** should test real interactions but complete quickly (<30s total)  
3. **Slow integration tests** can take longer but should be stable and not flaky

## Performance Improvements Made

1. **Separated slow MCP tests** from fast unit tests
2. **Fixed cache manager singleton stats** accumulation issues
3. **Corrected test expectations** to account for shared state
4. **Improved test isolation** with proper setup/teardown