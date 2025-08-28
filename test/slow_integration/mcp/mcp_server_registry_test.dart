import 'package:test/test.dart';

import '../../../mcp/mcp_server_context_manager.dart';
import '../../../mcp/mcp_server_dart.dart';
import '../../../mcp/mcp_server_puppeteer.dart';
import '../../../mcp/mcp_server_terminal.dart';

/// 🛡️ REGRESSION: MCP Server Basic RPC Response Test
///
/// This test ensures all MCP servers in the mcp/ directory can:
/// 1. Build and initialize without errors
/// 2. Respond to the basic "tools/list" RPC command
/// 3. Return a valid tools list response
///
/// **PERMANENT TEST FORTRESS**: This test prevents regressions in MCP server
/// basic functionality, ensuring the coding assistant can always communicate
/// with its MCP servers via RPC.
void main() {
  group('🛡️ MCP Server Basic RPC Tests', () {
    test('🧪 DART MCP SERVER: Basic RPC tools/list response', () async {
      // Arrange: Create Dart MCP server
      final server = DartMCPServer(
        enableDebugLogging: false,
        workingDirectory: '.',
        logger: (level, message, [data]) {
          // Silent logger for tests
        },
      );

      // Act: Initialize server and get tools list
      await server.initializeServer();
      final tools = server.getAvailableTools();

      // Assert: Verify basic response capability
      expect(tools, isNotEmpty,
          reason: 'Dart MCP server should return tools list');
      expect(tools.length, equals(3),
          reason: 'Dart MCP server should have 3 tools');

      // Verify tool names match expected
      final toolNames = tools.map((t) => t.name).toSet();
      expect(toolNames, contains('analyze_dart_code'));
      expect(toolNames, contains('fix_dart_code'));
      expect(toolNames, contains('execute_dart_app'));
    });

    test('🧪 TERMINAL MCP SERVER: Basic RPC tools/list response', () async {
      // Arrange: Create Terminal MCP server
      final server = TerminalMCPServer(
        enableDebugLogging: false,
        workingDirectory: '.',
        maxOutputSize: 1000000,
        logger: (level, message, [data]) {
          // Silent logger for tests
        },
      );

      // Act: Initialize server and get tools list
      await server.initializeServer();
      final tools = server.getAvailableTools();

      // Assert: Verify basic response capability
      expect(tools, isNotEmpty,
          reason: 'Terminal MCP server should return tools list');
      expect(tools.length, equals(1),
          reason: 'Terminal MCP server should have 1 tool');

      // Verify tool name matches expected
      final toolNames = tools.map((t) => t.name).toSet();
      expect(toolNames, contains('execute_terminal_command'));
    });

    test('🧪 CONTEXT MANAGER MCP SERVER: Basic RPC tools/list response',
        () async {
      // Arrange: Create Context Manager MCP server
      final server = ContextManagerMCPServer(
        logger: (level, message, [data]) {
          // Silent logger for tests
        },
      );

      // Act: Initialize server and get tools list
      await server.initializeServer();
      final tools = server.getAvailableTools();

      // Assert: Verify basic response capability
      expect(tools, isNotEmpty,
          reason: 'Context Manager MCP server should return tools list');
      expect(tools.length, equals(4),
          reason: 'Context Manager MCP server should have 4 tools');

      // Verify tool names match expected
      final toolNames = tools.map((t) => t.name).toSet();
      expect(toolNames, contains('analyze_context'));
      expect(toolNames, contains('add_to_context'));
      expect(toolNames, contains('save_session'));
      expect(toolNames, contains('get_context_status'));
    });

    test('🧪 PUPPETEER MCP SERVER: Basic RPC tools/list response', () async {
      // Arrange: Create Puppeteer MCP server
      final server = PuppeteerMCPServer(
        headless: true,
        navigationTimeout: Duration(seconds: 30),
        logger: (level, message, [data]) {
          // Silent logger for tests
        },
      );

      // Act: Initialize server and get tools list
      await server.initializeServer();
      final tools = server.getAvailableTools();

      // Assert: Verify basic response capability
      expect(tools, isNotEmpty,
          reason: 'Puppeteer MCP server should return tools list');
      expect(tools.length, equals(2),
          reason: 'Puppeteer MCP server should have 2 tools');

      // Verify tool names match expected
      final toolNames = tools.map((t) => t.name).toSet();
      expect(toolNames, contains('puppeteer_navigate'));
      expect(toolNames, contains('puppeteer_get_inner_text'));
    });

    test('🧪 INTEGRATION: All MCP servers respond to basic RPC commands',
        () async {
      // Arrange: Create all MCP servers
      final servers = [
        DartMCPServer(logger: (level, message, [data]) {}),
        TerminalMCPServer(logger: (level, message, [data]) {}),
        ContextManagerMCPServer(logger: (level, message, [data]) {}),
        PuppeteerMCPServer(logger: (level, message, [data]) {}),
      ];

      // Act: Initialize all servers and get tools lists
      for (final server in servers) {
        await server.initializeServer();
      }

      // Assert: All servers should respond with tools
      for (final server in servers) {
        final tools = server.getAvailableTools();
        expect(tools, isNotEmpty,
            reason: 'Server ${server.name} should respond with tools list');

        // Each tool should have basic required fields
        for (final tool in tools) {
          expect(tool.name, isNotEmpty,
              reason: 'Tool name should not be empty');
          expect(tool.description, isNotEmpty,
              reason: 'Tool description should not be empty');
          expect(tool.callback, isNotNull,
              reason: 'Tool callback should be implemented');
        }
      }

      // Verify total tool count across all servers
      final totalTools = servers.fold<int>(
          0, (sum, server) => sum + server.getAvailableTools().length);
      expect(totalTools, equals(10),
          reason: 'Total tools across all servers should be 10 (3+1+4+2)');
    });
  });
}
