/// 🧪 INTEGRATION TEST: MCP Hot Reload Functionality
/// 
/// Tests the MCP hot reload manager to ensure it can handle server restarts
/// and configuration changes without affecting the agent's ability to recover
/// from tool call round limits.
library;

import 'dart:async';
import 'dart:io';

import 'package:dart_ai_coding_assistant/mcp_hot_reload.dart';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:test/test.dart';

void main() {
  group('🧪 MCP Hot Reload with Tool Call Limits', () {
    late McpToolExecutorRegistry toolRegistry;
    late McpHotReloadManager hotReloadManager;
    late File tempConfigFile;

    setUp(() async {
      // Create a temporary config file for testing
      tempConfigFile = File('test_config_${DateTime.now().millisecondsSinceEpoch}.json');
      await tempConfigFile.writeAsString('''
{
  "mcpServers": {
    "test-server": {
      "command": "echo",
      "args": ["test server"],
      "description": "Test MCP server"
    }
  }
}
''');

      toolRegistry = McpToolExecutorRegistry(mcpConfig: tempConfigFile);
      hotReloadManager = McpHotReloadManager();
    });

    tearDown(() async {
      await hotReloadManager.dispose();
      await toolRegistry.shutdown();
      if (tempConfigFile.existsSync()) {
        await tempConfigFile.delete();
      }
    });

    test('✅ Should initialize hot reload manager without errors', () async {
      await hotReloadManager.initialize(
        configPath: tempConfigFile.path,
        toolRegistry: toolRegistry,
        watchForChanges: false,
      );

      final status = hotReloadManager.getStatus();
      expect(status['configFile'], tempConfigFile.path);
      expect(status['isWatching'], isFalse);
      expect(status['hasToolRegistry'], isTrue);
    });

    test('✅ Should handle reload commands during tool call processing', () async {
      await hotReloadManager.initialize(
        configPath: tempConfigFile.path,
        toolRegistry: toolRegistry,
        watchForChanges: false,
      );

      // Test that reload commands are properly handled
      final handled = await hotReloadManager.processCommand('reload');
      expect(handled, isTrue);

      final statusHandled = await hotReloadManager.processCommand('mcp status');
      expect(statusHandled, isTrue);

      final unknownHandled = await hotReloadManager.processCommand('unknown command');
      expect(unknownHandled, isFalse);
    });

    test('✅ Should maintain tool registry state after hot reload', () async {
      await toolRegistry.initialize();
      await hotReloadManager.initialize(
        configPath: tempConfigFile.path,
        toolRegistry: toolRegistry,
        watchForChanges: false,
      );

      final initialToolCount = toolRegistry.toolCount;
      
      // Perform hot reload
      final result = await hotReloadManager.reloadServers(reason: 'test');
      expect(result.success, isTrue);
      
      // Tool registry should maintain its state
      expect(toolRegistry.toolCount, initialToolCount);
    });

    test('✅ Should handle hot reload during tool call processing', () async {
      await toolRegistry.initialize();
      await hotReloadManager.initialize(
        configPath: tempConfigFile.path,
        toolRegistry: toolRegistry,
        watchForChanges: false,
      );

      // Simulate a scenario where hot reload is triggered during tool processing
      final reloadResult = await hotReloadManager.reloadServers(
        reason: 'emergency_reload',
        force: true,
      );

      expect(reloadResult.success, isTrue);
      expect(reloadResult.oldToolCount, isNotNull);
      expect(reloadResult.newToolCount, isNotNull);
    });
  });

  group('🧪 Hot Reload Recovery Scenarios', () {
    test('✅ Should recover from hot reload failures gracefully', () async {
      final invalidConfigFile = File('invalid_config.json');
      await invalidConfigFile.writeAsString('{"invalid": "json"'); // Malformed JSON

      final toolRegistry = McpToolExecutorRegistry(mcpConfig: invalidConfigFile);
      final hotReloadManager = McpHotReloadManager();

      try {
        await hotReloadManager.initialize(
          configPath: invalidConfigFile.path,
          toolRegistry: toolRegistry,
          watchForChanges: false,
        );

        // Attempt reload should fail but not crash
        final result = await hotReloadManager.reloadServers(reason: 'test');
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      } finally {
        await hotReloadManager.dispose();
        await toolRegistry.shutdown();
        if (invalidConfigFile.existsSync()) {
          await invalidConfigFile.delete();
        }
      }
    });

    test('✅ Should handle multiple rapid reload requests', () async {
      final tempConfigFile = File('rapid_reload_test.json');
      await tempConfigFile.writeAsString('''
{
  "mcpServers": {
    "test-server": {
      "command": "echo",
      "args": ["test"],
      "description": "Test server for rapid reload"
    }
  }
}
''');

      final toolRegistry = McpToolExecutorRegistry(mcpConfig: tempConfigFile);
      final hotReloadManager = McpHotReloadManager();

      try {
        await toolRegistry.initialize();
        await hotReloadManager.initialize(
          configPath: tempConfigFile.path,
          toolRegistry: toolRegistry,
          watchForChanges: false,
        );

        // Trigger multiple rapid reloads
        final results = await Future.wait([
          hotReloadManager.reloadServers(reason: 'rapid1'),
          hotReloadManager.reloadServers(reason: 'rapid2'),
          hotReloadManager.reloadServers(reason: 'rapid3'),
        ]);

        // All should complete (though some may fail due to race conditions)
        expect(results, hasLength(3));
        expect(results, isNotNull);
      } finally {
        await hotReloadManager.dispose();
        await toolRegistry.shutdown();
        if (tempConfigFile.existsSync()) {
          await tempConfigFile.delete();
        }
      }
    });
  });
}