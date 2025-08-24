/// 🚀 MCP HOT RELOAD: Dynamic MCP Server Management
///
/// Provides hot reload capabilities for MCP servers without restarting
/// the main application. Supports both manual reload commands and
/// automatic configuration file monitoring.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';

/// 🔥 MCP HOT RELOAD MANAGER: Dynamic server lifecycle management
///
/// Manages MCP server hot reloading with:
/// - Configuration file monitoring
/// - Manual reload commands
/// - Graceful server transitions
/// - State preservation
class McpHotReloadManager {
  /// 🔒 SINGLETON: Global instance for hot reload management
  static final McpHotReloadManager _instance = McpHotReloadManager._internal();

  /// 🏭 FACTORY: Get singleton instance
  factory McpHotReloadManager() => _instance;

  /// 🔧 PRIVATE CONSTRUCTOR: Initialize singleton
  McpHotReloadManager._internal();

  /// 📁 CONFIG FILE: MCP server configuration file
  File? _configFile;

  /// 📊 CONFIG HASH: Last known configuration hash for change detection
  String? _lastConfigHash;

  /// 🔄 RELOAD STREAM: Stream controller for reload events
  final StreamController<McpReloadEvent> _reloadController =
      StreamController<McpReloadEvent>.broadcast();

  /// 📡 FILE WATCHER: File system watcher for config changes
  StreamSubscription<FileSystemEvent>? _fileWatcher;

  /// ⏰ RELOAD DEBOUNCE: Debounce timer for config changes
  Timer? _debounceTimer;

  /// 🔧 TOOL REGISTRY: Reference to the tool registry
  McpToolExecutorRegistry? _toolRegistry;

  /// 🚀 INITIALIZE: Set up hot reload manager
  ///
  /// [configPath] - Path to MCP configuration file
  /// [toolRegistry] - Tool registry to manage
  /// [watchForChanges] - Whether to automatically watch for config changes
  Future<void> initialize({
    required String configPath,
    required McpToolExecutorRegistry toolRegistry,
    bool watchForChanges = true,
  }) async {
    _configFile = File(configPath);
    _toolRegistry = toolRegistry;

    if (!_configFile!.existsSync()) {
      throw Exception('MCP configuration file not found: $configPath');
    }

    // Store initial config hash
    _lastConfigHash = await _computeConfigHash();

    if (watchForChanges) {
      await _startConfigWatching();
    }

    print('✅ MCP Hot Reload Manager initialized');
  }

  /// 📡 START CONFIG WATCHING: Monitor config file for changes
  Future<void> _startConfigWatching() async {
    if (_configFile == null) {
      throw Exception('Hot reload manager not initialized');
    }

    final configDir = _configFile!.parent;

    try {
      _fileWatcher = configDir.watch(events: FileSystemEvent.modify).listen(
        (event) async {
          if (event.path == _configFile!.path) {
            await _handleConfigChange();
          }
        },
        onError: (Object error) {
          print('⚠️  Config file watch error: $error');
        },
      );

      print('👀 Watching MCP config for changes: ${_configFile!.path}');
    } catch (e) {
      print('⚠️  Could not start config file watching: $e');
    }
  }

  /// 🔄 HANDLE CONFIG CHANGE: Process configuration file changes
  Future<void> _handleConfigChange() async {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final newHash = await _computeConfigHash();

        if (newHash != _lastConfigHash) {
          print('🔄 MCP configuration changed, triggering reload...');
          _lastConfigHash = newHash;
          await reloadServers(reason: 'config_changed');
        }
      } catch (e) {
        print('⚠️  Error processing config change: $e');
      }
    });
  }

  /// 🔢 COMPUTE CONFIG HASH: Generate hash for config file content
  Future<String> _computeConfigHash() async {
    if (_configFile == null) {
      return '';
    }

    final content = await _configFile!.readAsString();
    final bytes = utf8.encode(content);

    // Simple hash function for change detection
    var hash = 0;
    for (final byte in bytes) {
      hash = (hash << 5) - hash + byte;
      hash = hash & hash; // Convert to 32-bit integer
    }

    return hash.toString();
  }

  /// 🔄 RELOAD SERVERS: Hot reload all MCP servers
  ///
  /// [reason] - Reason for reload (for logging)
  /// [force] - Force reload even if config hasn't changed
  Future<McpReloadResult> reloadServers({
    String reason = 'manual',
    bool force = false,
  }) async {
    if (_toolRegistry == null) {
      throw Exception('Tool registry not set');
    }

    final startTime = DateTime.now();
    print('🔄 Starting MCP server hot reload (reason: $reason)...');

    try {
      // Notify listeners about reload start (if controller is still open)
      if (!_reloadController.isClosed) {
        _reloadController.add(McpReloadEvent(
          type: McpReloadEventType.start,
          reason: reason,
          timestamp: DateTime.now(),
        ));
      }

      // Get current status before reload
      final oldStatus = _toolRegistry!.getStatus();

      // Shutdown current registry
      await _toolRegistry!.shutdown();

      // Reinitialize with new configuration
      await _toolRegistry!.initialize();

      // Get new status after reload
      final newStatus = _toolRegistry!.getStatus();

      final duration = DateTime.now().difference(startTime);

      final result = McpReloadResult(
        success: true,
        duration: duration,
        oldServerCount: (oldStatus['mcpClientCount'] as int?) ?? 0,
        newServerCount: (newStatus['mcpClientCount'] as int?) ?? 0,
        oldToolCount: (oldStatus['toolCount'] as int?) ?? 0,
        newToolCount: (newStatus['toolCount'] as int?) ?? 0,
        reason: reason,
      );

      print(
          '✅ MCP server hot reload completed in ${duration.inMilliseconds}ms');
      print(
          '   📊 Servers: ${result.oldServerCount} → ${result.newServerCount}');
      print('   🛠️  Tools: ${result.oldToolCount} → ${result.newToolCount}');

      // Notify listeners about reload completion (if controller is still open)
      if (!_reloadController.isClosed) {
        _reloadController.add(McpReloadEvent(
          type: McpReloadEventType.complete,
          reason: reason,
          timestamp: DateTime.now(),
          result: result,
        ));
      }

      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      print('❌ MCP server hot reload failed: $e');

      // Notify listeners about reload failure (if controller is still open)
      if (!_reloadController.isClosed) {
        _reloadController.add(McpReloadEvent(
          type: McpReloadEventType.error,
          reason: reason,
          timestamp: DateTime.now(),
          error: e.toString(),
        ));
      }

      return McpReloadResult(
        success: false,
        duration: duration,
        error: e.toString(),
        reason: reason,
      );
    }
  }

  /// 📋 GET STATUS: Get current hot reload manager status
  Map<String, dynamic> getStatus() {
    return {
      'isWatching': _fileWatcher != null,
      'configFile': _configFile?.path,
      'lastConfigHash': _lastConfigHash,
      'hasToolRegistry': _toolRegistry != null,
    };
  }

  /// 📡 RELOAD STREAM: Stream of reload events
  Stream<McpReloadEvent> get reloadStream => _reloadController.stream;

  /// 🧹 DISPOSE: Clean up resources
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _fileWatcher?.cancel();
    await _reloadController.close();

    print('✅ MCP Hot Reload Manager disposed');
  }

  /// 🎯 RELOAD COMMAND: Process reload command from user input
  ///
  /// [command] - User command to process
  /// Returns true if command was handled, false otherwise
  Future<bool> processCommand(String command) async {
    final normalized = command.trim().toLowerCase();

    if (normalized == 'reload' || normalized == 'mcp reload') {
      await reloadServers(reason: 'user_command');
      return true;
    }

    if (normalized == 'mcp status') {
      final status = getStatus();
      final registryStatus = _toolRegistry?.getStatus() ?? {};

      print('📊 MCP Hot Reload Status:');
      print('   👀 Config Watching: ${status['isWatching']}');
      print('   📁 Config File: ${status['configFile']}');
      print('   🔧 Tool Registry: ${status['hasToolRegistry']}');
      print('   🖥️  Active Servers: ${registryStatus['mcpClientCount'] ?? 0}');
      print('   🛠️  Available Tools: ${registryStatus['toolCount'] ?? 0}');

      return true;
    }

    return false;
  }
}

/// 🎯 MCP RELOAD EVENT: Event emitted during hot reload
class McpReloadEvent {
  /// 🎯 EVENT TYPE: The type of reload event (start, complete, or error)
  final McpReloadEventType type;

  /// 📝 REASON: Human-readable description of why the reload was triggered
  final String reason;

  /// ⏰ TIMESTAMP: When the event occurred
  final DateTime timestamp;

  /// 📊 RESULT: The result of the reload operation (null for start events)
  final McpReloadResult? result;

  /// ❌ ERROR: Error message if the reload failed (null for successful operations)
  final String? error;

  /// 🏗️ CONSTRUCTOR: Creates a new MCP reload event
  ///
  /// [type] - The type of reload event
  /// [reason] - Human-readable description of why the reload was triggered
  /// [timestamp] - When the event occurred
  /// [result] - The result of the reload operation (null for start events)
  /// [error] - Error message if the reload failed (null for successful operations)
  McpReloadEvent({
    required this.type,
    required this.reason,
    required this.timestamp,
    this.result,
    this.error,
  });

  @override
  String toString() {
    return 'McpReloadEvent{type: $type, reason: $reason, timestamp: $timestamp}';
  }
}

/// 🎯 MCP RELOAD EVENT TYPE: Types of reload events
enum McpReloadEventType {
  /// 🚀 START: Reload operation has begun
  start,

  /// ✅ COMPLETE: Reload operation finished successfully
  complete,

  /// 💥 ERROR: Reload operation failed with an error
  error,
}

/// 📊 MCP RELOAD RESULT: Result of a hot reload operation
class McpReloadResult {
  /// ✅ SUCCESS: Whether the reload operation completed successfully
  final bool success;

  /// ⏱️ DURATION: How long the reload operation took
  final Duration duration;

  /// 📊 OLD SERVER COUNT: Number of servers before reload
  final int? oldServerCount;

  /// 📊 NEW SERVER COUNT: Number of servers after reload
  final int? newServerCount;

  /// 🛠️ OLD TOOL COUNT: Number of tools before reload
  final int? oldToolCount;

  /// 🛠️ NEW TOOL COUNT: Number of tools after reload
  final int? newToolCount;

  /// ❌ ERROR: Error message if reload failed
  final String? error;

  /// 📝 REASON: Why the reload was triggered
  final String reason;

  /// 🏗️ CONSTRUCTOR: Creates a new MCP reload result
  ///
  /// [success] - Whether the reload operation completed successfully
  /// [duration] - How long the reload operation took
  /// [oldServerCount] - Number of servers before reload
  /// [newServerCount] - Number of servers after reload
  /// [oldToolCount] - Number of tools before reload
  /// [newToolCount] - Number of tools after reload
  /// [error] - Error message if reload failed
  /// [reason] - Why the reload was triggered
  McpReloadResult({
    required this.success,
    required this.duration,
    this.oldServerCount,
    this.newServerCount,
    this.oldToolCount,
    this.newToolCount,
    this.error,
    required this.reason,
  });

  @override
  String toString() {
    return 'McpReloadResult{success: $success, duration: $duration, '
        'servers: $oldServerCount→$newServerCount, tools: $oldToolCount→$newToolCount}';
  }
}
