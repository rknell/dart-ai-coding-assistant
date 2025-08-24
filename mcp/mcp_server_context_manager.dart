import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';

/// CONTEXT MANAGER MCP SERVER: Intelligent Context Optimization
/// Provides context management capabilities for AI agents
class ContextManagerMCPServer extends BaseMCPServer {
  final Map<String, Map<String, dynamic>> _contextHistory = <String, Map<String, dynamic>>{};
  final Map<String, int> _contextVersions = <String, int>{};

  ContextManagerMCPServer({
    super.name = 'context-manager',
    super.version = '1.0.0',
    super.logger,
  });

  @override
  Future<void> initializeServer() async {
    // Context analysis tools
    registerTool(MCPTool(
      name: 'analyze_context',
      description: 'Analyze context for complexity and optimization opportunities',
      inputSchema: {
        'type': 'object',
        'properties': {
          'context': {'type': 'string', 'description': 'Context to analyze'},
        },
        'required': ['context'],
      },
      callback: _handleAnalyzeContext,
    ));

    // Context management tools
    registerTool(MCPTool(
      name: 'add_to_context',
      description: 'Add content to context and track token usage',
      inputSchema: {
        'type': 'object',
        'properties': {
          'content': {'type': 'string', 'description': 'Content to add'},
        },
        'required': ['content'],
      },
      callback: _handleAddToContext,
    ));

    registerTool(MCPTool(
      name: 'save_session',
      description: 'Save current session state for crash recovery',
      inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
      callback: _handleSaveSession,
    ));

    registerTool(MCPTool(
      name: 'get_context_status',
      description: 'Get current context status and statistics',
      inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
      callback: _handleGetContextStatus,
    ));

    logger?.call('info', 'Context Manager MCP server initialized');
  }

  Future<MCPToolResult> _handleAnalyzeContext(Map<String, dynamic> arguments) async {
    final context = arguments['context'] as String;
    
    try {
      final metrics = _calculateContextMetrics(context);
      final result = {
        'success': true,
        'analysis': {
          'originalLength': context.length,
          'metrics': metrics,
        },
      };

      return MCPToolResult(content: [MCPContent.text(jsonEncode(result))]);
    } catch (e) {
      throw MCPServerException('Context analysis failed: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleAddToContext(Map<String, dynamic> parameters) async {
    final content = parameters['content'] as String;
    final contextId = 'context_${DateTime.now().millisecondsSinceEpoch}';
    
    _contextHistory[contextId] = {
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };

    return MCPToolResult(content: [
      MCPContent.text(jsonEncode({
        'success': true,
        'context_id': contextId,
        'content_length': content.length,
        'total_contexts': _contextHistory.length,
      })),
    ]);
  }

  Future<MCPToolResult> _handleSaveSession(Map<String, dynamic> parameters) async {
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    
    _contextHistory[sessionId] = {
      'content': jsonEncode({
        'session_id': sessionId,
        'context_count': _contextHistory.length,
        'saved_at': DateTime.now().toIso8601String(),
      }),
      'timestamp': DateTime.now().toIso8601String(),
    };

    return MCPToolResult(content: [
      MCPContent.text(jsonEncode({
        'success': true,
        'session_id': sessionId,
        'context_count': _contextHistory.length,
      })),
    ]);
  }

  Future<MCPToolResult> _handleGetContextStatus(Map<String, dynamic> parameters) async {
    final totalContexts = _contextHistory.length;
    final totalContentLength = _contextHistory.values
        .map((c) => (c['content'] as String).length)
        .reduce((a, b) => a + b);

    final status = {
      'total_contexts': totalContexts,
      'total_content_length': totalContentLength,
      'last_updated': DateTime.now().toIso8601String(),
    };

    return MCPToolResult(content: [
      MCPContent.text(jsonEncode({
        'success': true,
        'status': status,
      })),
    ]);
  }

  Map<String, dynamic> _calculateContextMetrics(String context) {
    final words = context.split(' ').length;
    final sentences = context.split(RegExp(r'[.!?]+')).length;
    
    return {
      'length': {
        'characters': context.length,
        'words': words,
        'sentences': sentences,
      },
      'density': {
        'wordsPerSentence': words / sentences,
        'charactersPerWord': context.length / words,
      },
    };
  }

  @override
  Future<void> shutdown() async {
    _contextHistory.clear();
    _contextVersions.clear();
    await super.shutdown();
  }
}

/// Main entry point
void main() async {
  final server = ContextManagerMCPServer(
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
    stderr.writeln('Failed to start Context Manager MCP server: $e');
    exit(1);
  }
}