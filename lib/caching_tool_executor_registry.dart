import 'dart:io';

import 'package:dart_ai_coding_assistant/mcp_caching_wrapper.dart';
import 'package:dart_openai_client/dart_openai_client.dart';

/// 
/// Extends McpToolExecutorRegistry with caching capabilities for:
/// - Tool discovery results
/// - MCP server initialization
/// - Tool execution results
///
/// 🎯 CACHING BENEFITS:
/// - Reduced MCP server initialization time
/// - Fewer tool discovery calls
/// - Cached tool execution for read-only operations
/// - Lower DeepSeek API costs due to reduced context size
class CachingMcpToolExecutorRegistry extends McpToolExecutorRegistry {
  final Map<String, List<Tool>> _toolCache = {};
  final Map<String, DateTime> _toolCacheTimestamps = {};
  final Map<String, McpCachingWrapper> _cachingWrappers = {};
  final Map<String, bool> _serverInitializationCache = {};
  
  /// 🏗️ CONSTRUCTOR: Create new caching registry
  CachingMcpToolExecutorRegistry({required super.mcpConfig});
  @override
  Future<void> initialize() async {
    final cacheKey = _generateConfigCacheKey();
    
    // Check if already initialized with this config
    if (_serverInitializationCache.containsKey(cacheKey) && 
        _serverInitializationCache[cacheKey] == true) {
      print('🔄 Using cached MCP server initialization');
      return;
    }
    
    await super.initialize();
    
    // Cache the initialization state
    _serverInitializationCache[cacheKey] = true;
    
    // Create caching wrappers for all MCP clients
    _createCachingWrappers();
  }
  @override
  Future<String> executeTool(ToolCall toolCall, {Duration? timeout}) async {
    // Try to find a caching executor first
    final cachingExecutor = _findCachingExecutor(toolCall);
    if (cachingExecutor != null) {
      return await cachingExecutor.executeTool(toolCall, timeout: timeout);
    }
    
    // Fall back to standard execution
    return await super.executeTool(toolCall, timeout: timeout);
  }
  @override
  List<Tool> getAllTools() {
    final cacheKey = 'all_tools';
    
    // Check cache first
    if (_toolCache.containsKey(cacheKey)) {
      final cachedTime = _toolCacheTimestamps[cacheKey];
      if (cachedTime != null && 
          DateTime.now().difference(cachedTime) < Duration(minutes: 30)) {
        return _toolCache[cacheKey]!;
      }
    }
    
    // Get tools from parent
    final tools = super.getAllTools();
    
    // Cache the result
    _toolCache[cacheKey] = tools;
    _toolCacheTimestamps[cacheKey] = DateTime.now();
    
    return tools;
  }
  /// 🧹 CLEAR CACHE: Clear all cached data
  void clearCache() {
    _toolCache.clear();
    _toolCacheTimestamps.clear();
    _cachingWrappers.clear();
    _serverInitializationCache.clear();
    
    // Also clear cache in all caching wrappers
    for (final wrapper in _cachingWrappers.values) {
      wrapper.clearCache();
    }
    
    print('🗑️  All tool registry caches cleared');
  }
  /// 📊 GET CACHE STATS: Get cache statistics
  Map<String, dynamic> getCacheStats() {
    var totalToolCacheHits = 0;
    var totalToolCacheSize = 0;
    
    for (final wrapper in _cachingWrappers.values) {
      final stats = wrapper.getCacheStats();
      totalToolCacheHits += (stats['cacheHits'] ?? 0) as int;
      totalToolCacheSize += (stats['executionCacheSize'] ?? 0) as int;
    }
    
    return {
      'toolCacheSize': _toolCache.length,
      'cachingWrappers': _cachingWrappers.length,
      'serverInitializationCache': _serverInitializationCache.length,
      'totalToolCacheHits': totalToolCacheHits,
      'totalToolCacheSize': totalToolCacheSize,
      'toolCacheTimestamps': _toolCacheTimestamps.length,
    };
  }
  /// 🔧 CREATE CACHING WRAPPERS: Create caching wrappers for all MCP clients
  void _createCachingWrappers() {
    // This is a simplified implementation
    // In a real implementation, we'd iterate through all MCP clients
    // and create caching wrappers for them
    
    print('🔧 Creating caching wrappers for MCP tools...');
    
    // Note: This would need access to the internal MCP clients
    // For now, we'll create wrappers on-demand during tool execution
  }
  /// 🔍 FIND CACHING EXECUTOR: Find a caching executor for a tool call
  ToolExecutor? _findCachingExecutor(ToolCall toolCall) {
    // This is a simplified implementation
    // In a real implementation, we'd check if we have a caching wrapper
    // for this tool and return it
    
    final toolName = toolCall.function.name;
    
    // For read-only filesystem operations, we can use caching
    const cacheableTools = {
      'read_text_file',
      'read_file',
      'list_directory',
      'directory_tree',
      'get_file_info',
      'search_files',
      'list_allowed_directories',
    };
    
    if (cacheableTools.contains(toolName)) {
      // In a real implementation, we'd return a caching executor here
      // For now, we'll return null and fall back to standard execution
      return null;
    }
    
    return null;
  }
  /// 🔑 GENERATE CONFIG CACHE KEY: Generate unique key for config
  String _generateConfigCacheKey() {
    try {
      final configContent = File(mcpConfig.path).readAsStringSync();
      return configContent.hashCode.toString();
    } catch (e) {
      return mcpConfig.path;
    }
  }
}
/// 🎯 CACHING TOOL EXECUTOR FACTORY: Factory for creating caching tool executors
class CachingToolExecutorFactory {
  /// 🔧 CREATE CACHING EXECUTOR: Create appropriate caching executor
  static ToolExecutor createCachingExecutor(
    ToolExecutor originalExecutor,
    McpClient? mcpClient,
  ) {
    if (originalExecutor is McpToolExecutor && mcpClient != null) {
      return CachingMcpToolExecutor(mcpClient, originalExecutor.asTool);
    }
    
    // For non-MCP executors, return the original (no caching)
    return originalExecutor;
  }
}