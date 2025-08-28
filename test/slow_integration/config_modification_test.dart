/// 🧪 TEST: MCP Configuration Modification
/// 
/// Script to test MCP config file modification and hot reload detection
library;

import 'dart:convert';
import 'dart:io';

void main() async {
  print("🧪 Testing MCP Configuration Modification");
  print("=" * 50);

  final configPath = "config/mcp_servers.json";
  final configFile = File(configPath);
  
  if (!configFile.existsSync()) {
    print("❌ Config file not found: $configPath");
    return;
  }

  try {
    // Read current config
    final currentConfig = await configFile.readAsString();
    final configData = jsonDecode(currentConfig) as Map<String, dynamic>;
    
    print("📋 Current MCP servers:");
    final servers = configData['mcpServers'] as Map<String, dynamic>;
    servers.forEach((name, config) {
      print("   🔧 $name: ${config['command']} ${config['args'].join(' ')}");
    });
    
    // Create backup
    final backupPath = "$configPath.backup";
    await configFile.copy(backupPath);
    print("✅ Backup created: $backupPath");
    
    // Test 1: Add a comment to the config
    print("\n📝 Test 1: Adding comment to config");
    final modifiedConfig1 = {
      ...configData,
      '_test_comment': 'Modified by test script at ${DateTime.now()}',
    };
    
    await configFile.writeAsString(
      JsonEncoder.withIndent('  ').convert(modifiedConfig1),
    );
    
    print("✅ Config modified with comment");
    print("💤 Waiting 2 seconds for hot reload detection...");
    await Future<void>.delayed(Duration(seconds: 2));
    
    // Test 2: Remove the comment
    print("\n📝 Test 2: Removing comment from config");
    await configFile.writeAsString(
      JsonEncoder.withIndent('  ').convert(configData),
    );
    
    print("✅ Config restored to original");
    print("💤 Waiting 2 seconds for hot reload detection...");
    await Future<void>.delayed(Duration(seconds: 2));
    
    // Test 3: Add a mock server
    print("\n📝 Test 3: Adding mock server to config");
    final modifiedConfig3 = {
      ...configData,
      'mcpServers': {
        ...servers,
        'mock-test-server': {
          'command': 'echo',
          'args': ['"Mock MCP Server"'],
          'description': 'Mock server for testing hot reload',
        },
      },
    };
    
    await configFile.writeAsString(
      JsonEncoder.withIndent('  ').convert(modifiedConfig3),
    );
    
    print("✅ Mock server added to config");
    print("💤 Waiting 2 seconds for hot reload detection...");
    await Future<void>.delayed(Duration(seconds: 2));
    
    // Restore original config
    print("\n🔄 Restoring original config");
    await configFile.writeAsString(currentConfig);
    
    // Clean up backup
    await File(backupPath).delete();
    
    print("✅ Original config restored");
    print("✅ Backup cleaned up");
    print("\n🎉 Configuration modification test completed!");
    print("\n📋 Next steps:");
    print("   1. Run the main application with hot reload enabled");
    print("   2. Modify config/mcp_servers.json while it's running");
    print("   3. Watch for automatic hot reload notifications");
    print("   4. Use 'reload' command to manually trigger reloads");
    
  } catch (e) {
    print("❌ Test failed: $e");
    
    // Try to restore backup if it exists
    try {
      final backupPath = "$configPath.backup";
      if (File(backupPath).existsSync()) {
        await File(backupPath).copy(configPath);
        await File(backupPath).delete();
        print("✅ Config restored from backup");
      }
    } catch (e2) {
      print("⚠️  Failed to restore config: $e2");
    }
  }
}