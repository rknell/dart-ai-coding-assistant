import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';

/// DART MCP SERVER: Dart Development Operations
/// Provides Dart development capabilities for AI agents
class DartMCPServer extends BaseMCPServer {
  final bool enableDebugLogging;
  final Duration executionTimeout;
  final String workingDirectory;

  DartMCPServer({
    super.name = 'dart-dev',
    super.version = '1.0.0',
    super.logger,
    this.enableDebugLogging = false,
    this.executionTimeout = const Duration(minutes: 5),
    this.workingDirectory = '.',
  });

  @override
  Future<void> initializeServer() async {
    // Code analysis tools
    registerTool(MCPTool(
      name: 'analyze_dart_code',
      description: 'Analyze Dart code using dart analyze',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description': 'Target to analyze',
            'default': '.',
          },
        },
        'required': ['target'],
      },
      callback: _handleAnalyzeDartCode,
    ));

    // Code fixing tools
    registerTool(MCPTool(
      name: 'fix_dart_code',
      description: 'Automatically fix common Dart code issues',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description': 'Target to fix',
            'default': '.',
          },
        },
        'required': ['target'],
      },
      callback: _handleFixDartCode,
    ));

    // Execution tools
    registerTool(MCPTool(
      name: 'execute_dart_app',
      description: 'Execute a Dart application',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target': {
            'type': 'string',
            'description': 'Dart file to execute',
            'default': 'main.dart',
          },
        },
        'required': ['target'],
      },
      callback: _handleExecuteDartApp,
    ));

    logger?.call('info', 'Dart MCP server initialized');
  }

  Future<MCPToolResult> _handleAnalyzeDartCode(Map<String, dynamic> arguments) async {
    final target = arguments['target'] as String? ?? '.';
    
    try {
      final result = await Process.run('dart', ['analyze', target]);
      
      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': result.exitCode == 0,
          'exitCode': result.exitCode,
          'stdout': result.stdout,
          'stderr': result.stderr,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Dart analysis failed: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleFixDartCode(Map<String, dynamic> arguments) async {
    final target = arguments['target'] as String? ?? '.';
    
    try {
      final result = await Process.run('dart', ['fix', '--apply', target]);
      
      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': result.exitCode == 0,
          'exitCode': result.exitCode,
          'stdout': result.stdout,
          'stderr': result.stderr,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Dart fix failed: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleExecuteDartApp(Map<String, dynamic> arguments) async {
    final target = arguments['target'] as String? ?? 'main.dart';
    
    try {
      final result = await Process.run('dart', [target]);
      
      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': result.exitCode == 0,
          'exitCode': result.exitCode,
          'stdout': result.stdout,
          'stderr': result.stderr,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Dart execution failed: ${e.toString()}');
    }
  }
}

/// Main entry point
void main() async {
  final server = DartMCPServer(
    logger: (level, message, [data]) {
      if (level == 'error' || level == 'info') {
        final timestamp = DateTime.now().toIso8601String();
        stderr.writeln('[$timestamp] [$level] $message');
      }
    },
  );

  try {
    await server.start();
  } catch (e) {
    stderr.writeln('Failed to start Dart MCP server: $e');
    exit(1);
  }
}