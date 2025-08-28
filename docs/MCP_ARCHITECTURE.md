# 🏗️ MCP Server Architecture Guide

## Overview
This document provides a comprehensive guide to the MCP (Model Context Protocol) server architecture used in this project. Future agents can reference this to understand how to create, extend, or maintain MCP servers.

## 📁 File Structure
```
mcp/
├── code_quality_mcp_server.dart      # Code quality analysis
├── mcp_server_dart.dart               # Dart development operations  
├── mcp_server_filesystem.dart         # File system operations
├── mcp_server_terminal.dart           # Terminal/shell operations
├── mcp_server_lsp.dart               # Language Server Protocol
├── mcp_server_context_manager.dart    # Context management
├── mcp_server_puppeteer.dart         # Browser automation
└── mcp_server_testing.dart           # Testing framework
```

## 🛠️ Base Architecture

### Core Components
All MCP servers extend `BaseMCPServer` from `dart_openai_client` package:

```dart
import 'package:dart_openai_client/dart_openai_client.dart';

class YourMCPServer extends BaseMCPServer {
  // Required constructor
  YourMCPServer({
    super.name = 'your-server',        # Unique server name
    super.version = '1.0.0',           # Semantic version
    super.logger,                      # Optional logger
    // Your custom properties
  });

  @override
  Future<void> initializeServer() async {
    // Register all your tools here
    registerTool(MCPTool(...));
  }
}
```

### Tool Registration Pattern
```dart
registerTool(MCPTool(
  name: 'tool_name',                   # Unique tool identifier
  description: 'What this tool does',  # Clear description for AI
  inputSchema: {                       # JSON Schema for parameters
    'type': 'object',
    'properties': {
      'param_name': {
        'type': 'string',
        'description': 'Parameter description',
        'default': 'default_value',    # Optional default
      }
    }
  },
  handler: _toolHandler,               # Function to handle the tool
));
```

### Tool Handler Pattern
```dart
Future<McpToolResult> _toolHandler(Map<String, dynamic> args) async {
  try {
    // Extract and validate arguments
    final param = args['param_name'] ?? 'default';
    
    // Perform the operation
    final result = await doSomething(param);
    
    // Return success with structured data
    return McpToolResult.success({
      'status': 'success',
      'result': result,
      'metadata': { /* additional info */ }
    });
    
  } catch (e) {
    // Always handle errors gracefully
    return McpToolResult.error('Operation failed: $e');
  }
}
```

## 🎯 Design Patterns

### 1. Configuration Pattern
```dart
class YourMCPServer extends BaseMCPServer {
  final bool enableDebugLogging;
  final Duration executionTimeout;
  final String workingDirectory;
  final Map<String, dynamic> customConfig;

  YourMCPServer({
    super.name = 'your-server',
    super.version = '1.0.0', 
    super.logger,
    this.enableDebugLogging = false,
    this.executionTimeout = const Duration(minutes: 5),
    this.workingDirectory = '.',
    this.customConfig = const {},
  });
}
```

### 2. Phased Implementation Pattern
For complex servers, implement in phases:

```dart
@override
Future<void> initializeServer() async {
  // Phase 1: Core functionality
  _registerCoreTools();
  
  // Phase 2: Extended features  
  _registerExtendedTools();
  
  // Future phases as TODOs
  // TODO: Phase 3 - Advanced features
}

void _registerCoreTools() {
  registerTool(MCPTool(/* core tool 1 */));
  registerTool(MCPTool(/* core tool 2 */));
}
```

### 3. Error Handling Pattern
```dart
Future<McpToolResult> _handler(Map<String, dynamic> args) async {
  try {
    // Validate inputs first
    if (args['required_param'] == null) {
      return McpToolResult.error('Missing required parameter: required_param');
    }
    
    // Validate file/directory existence
    final path = args['path'] ?? '.';
    if (!Directory(path).existsSync() && !File(path).existsSync()) {
      return McpToolResult.error('Path does not exist: $path');
    }
    
    // Execute with timeout
    final result = await operation().timeout(executionTimeout);
    
    return McpToolResult.success(result);
    
  } on TimeoutException {
    return McpToolResult.error('Operation timed out after ${executionTimeout.inSeconds}s');
  } catch (e) {
    return McpToolResult.error('Operation failed: $e');
  }
}
```

### 4. Process Execution Pattern
```dart
Future<ProcessResult> _runCommand(List<String> command) async {
  return await Process.run(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
    runInShell: true,
  ).timeout(executionTimeout);
}
```

### 5. Debug Logging Pattern
```dart
void _logDebug(String message) {
  if (enableDebugLogging) {
    print('🔍 [${name.toUpperCase()}] $message');
  }
}
```

## 📋 JSON Schema Guidelines

### Common Parameter Types
```dart
// File/directory path
'path': {
  'type': 'string',
  'description': 'Path to file or directory',
  'default': '.',
}

// Boolean flag
'enabled': {
  'type': 'boolean', 
  'description': 'Enable/disable feature',
  'default': false,
}

// Enum selection
'format': {
  'type': 'string',
  'enum': ['json', 'text', 'html'],
  'description': 'Output format',
  'default': 'json',
}

// Timeout
'timeout_seconds': {
  'type': 'integer',
  'description': 'Timeout in seconds',
  'minimum': 1,
  'maximum': 300,
  'default': 30,
}
```

## 🧪 Testing Patterns

### Unit Test Structure
```dart
// test/unit/your_mcp_server_test.dart
import 'package:test/test.dart';
import '../mcp/your_mcp_server.dart';

void main() {
  group('YourMCPServer', () {
    late YourMCPServer server;
    
    setUp(() {
      server = YourMCPServer(enableDebugLogging: true);
    });
    
    test('should initialize with correct tools', () async {
      await server.initializeServer();
      expect(server.registeredTools.length, greaterThan(0));
    });
    
    test('should handle valid input', () async {
      final result = await server.toolHandler('tool_name', {
        'param': 'valid_value'
      });
      expect(result.isSuccess, isTrue);
    });
  });
}
```

## 🔧 Common Utilities

### File System Validation
```dart
bool _validatePath(String path) {
  return Directory(path).existsSync() || File(path).existsSync();
}
```

### Output Formatting
```dart
Map<String, dynamic> _formatResults(dynamic data, String format) {
  switch (format) {
    case 'json':
      return {'data': data, 'format': 'json'};
    case 'text': 
      return {'data': data.toString(), 'format': 'text'};
    default:
      return {'data': data};
  }
}
```

## 🚨 Best Practices

### 1. Always Validate Inputs
- Check required parameters exist
- Validate file paths before use
- Sanitize user input to prevent injection

### 2. Handle Timeouts
- Set reasonable timeout limits
- Handle TimeoutException explicitly
- Provide timeout configuration options

### 3. Provide Clear Error Messages  
- Include context about what failed
- Suggest possible solutions
- Use consistent error format

### 4. Structure Return Data
- Use consistent response format
- Include metadata (execution time, status, etc.)
- Support multiple output formats when useful

### 5. Enable Debug Logging
- Add debug logging throughout
- Make it configurable (off by default)
- Include timing information

### 6. Follow Naming Conventions
- Use snake_case for tool names
- Use descriptive parameter names
- Prefix server names meaningfully

## 📚 Reference Examples

### Simple Server (Single Tool)
See: `mcp_server_dart.dart` - Clean, focused implementation

### Complex Server (Multiple Phases)  
See: `code_quality_mcp_server.dart` - Phased implementation with comprehensive error handling

### File Operations
See: `mcp_server_filesystem.dart` - File system operations with proper validation

### Process Execution
See: `mcp_server_terminal.dart` - Command execution with timeout handling

## 🎯 Quick Start Checklist

Creating a new MCP server:
- [ ] Create new file in `mcp/` directory
- [ ] Extend `BaseMCPServer`
- [ ] Add constructor with configuration options
- [ ] Implement `initializeServer()` method
- [ ] Register tools with proper schemas
- [ ] Add error handling in all tool handlers
- [ ] Add debug logging
- [ ] Write unit tests
- [ ] Update this architecture doc if needed

This architecture ensures consistency, maintainability, and reliability across all MCP servers in the project.