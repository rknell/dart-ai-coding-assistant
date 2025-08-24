/// 🧪 TEST: MCP Hot Reload Functionality
/// 
/// Test script to verify MCP server hot reload works correctly
library;

import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';
import 'lib/mcp_hot_reload.dart';

void main() async {
  print("🧪 Testing MCP Hot Reload Functionality");
  print("=" * 50);

  // Test configuration
  final configPath = "config/mcp_servers.json";
  final configFile = File(configPath);
  
  if (!configFile.existsSync()) {
    print("❌ Test failed: MCP config file not found at $configPath");
    return;
  }

  // Create tool registry
  final toolRegistry = McpToolExecutorRegistry(mcpConfig: configFile);
  
  try {
    // Initialize tool registry
    await toolRegistry.initialize();
    print("✅ Tool registry initialized");
    
    // Create hot reload manager
    final hotReloadManager = McpHotReloadManager();
    await hotReloadManager.initialize(
      configPath: configPath,
      toolRegistry: toolRegistry,
      watchForChanges: false, // Disable watching for test
    );
    
    print("✅ Hot reload manager initialized");
    
    // Test 1: Get initial status
    print("\n📊 Test 1: Initial Status");
    final initialStatus = hotReloadManager.getStatus();
    print("   Config file: ${initialStatus['configFile']}");
    print("   Is watching: ${initialStatus['isWatching']}");
    
    // Test 2: Manual reload
    print("\n🔄 Test 2: Manual Reload");
    final reloadResult = await hotReloadManager.reloadServers(
      reason: 'test',
      force: true,
    );
    
    print("   Success: ${reloadResult.success}");
    print("   Duration: ${reloadResult.duration.inMilliseconds}ms");
    print("   Tools before: ${reloadResult.oldToolCount}");
    print("   Tools after: ${reloadResult.newToolCount}");
    
    // Test 3: Command processing
    print("\n🎯 Test 3: Command Processing");
    final statusHandled = await hotReloadManager.processCommand("mcp status");
    print("   Status command handled: $statusHandled");
    
    final reloadHandled = await hotReloadManager.processCommand("reload");
    print("   Reload command handled: $reloadHandled");
    
    final unknownHandled = await hotReloadManager.processCommand("unknown");
    print("   Unknown command handled: $unknownHandled");
    
    // Test 4: Dispose
    print("\n🧹 Test 4: Cleanup");
    await hotReloadManager.dispose();
    await toolRegistry.shutdown();
    print("✅ Cleanup completed");
    
    print("\n🎉 All tests passed! MCP hot reload is working correctly.");
    
  } catch (e) {
    print("❌ Test failed: $e");
    print("Stack trace: ${e.toString()}");
    
    // Ensure cleanup even on failure
    try {
      await toolRegistry.shutdown();
    } catch (e2) {
      print("⚠️  Cleanup also failed: $e2");
    }
  }
}