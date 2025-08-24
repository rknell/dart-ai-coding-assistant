import 'dart:convert';

import 'package:dart_openai_client/dart_openai_client.dart';

/// 🔧 MCP CACHING WRAPPER: Caching layer for MCP tool discovery and execution
///
/// Wraps MCP client operations with caching to reduce redundant:
/// - Tool discovery calls
/// - Tool execution results (for idempotent operations)
/// - Server initialization
///
/// 🎯 CACHING STRATEGY:
/// - Tool discovery: Cache until server restart
/// - Tool execution: Cache based on operation type and arguments
/// - Server status: Cache with short TTL
class McpCachingWrapper {
  final McpClient _mcpClient;
  final Map<String, List<Tool>> _toolCache = {};
  final Map<String, String> _executionCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// 🏗️ CONSTRUCTOR: Create new caching wrapper
  McpCachingWrapper(this._mcpClient);

  /// 🔍 GET TOOLS WITH CACHE: Get tools with caching
  ///
  /// Returns cached tools if available, otherwise discovers from server
  Future<List<Tool>> getToolsWithCache() async {
    final cacheKey = 'tools:${_mcpClient.hashCode}';

    if (_toolCache.containsKey(cacheKey)) {
      return _toolCache[cacheKey]!;
    }

    // Ensure client is initialized
    if (_mcpClient.toolCount == 0) {
      // This is a simplified approach - in real implementation,
      // we'd need to handle initialization properly
      print('⚠️  MCP client not initialized, tools may be empty');
    }

    final tools = _mcpClient.tools;
    _toolCache[cacheKey] = tools;
    _cacheTimestamps[cacheKey] = DateTime.now();

    return tools;
  }

  /// 🛠️ EXECUTE TOOL WITH CACHE: Execute tool with result caching
  ///
  /// [toolName] - Name of the tool to execute
  /// [arguments] - Tool arguments as JSON string
  /// [cacheable] - Whether this operation can be cached
  /// [ttl] - Time-to-live for cache entry
  ///
  /// Returns cached result if available and valid, otherwise executes tool
  Future<String> executeToolWithCache(
    String toolName,
    String arguments, {
    bool cacheable = true,
    Duration ttl = const Duration(minutes: 5),
    Duration? timeout,
  }) async {
    if (!cacheable) {
      return await _mcpClient.executeTool(toolName, arguments,
          timeout: timeout);
    }

    final cacheKey = _generateExecutionCacheKey(toolName, arguments);

    // Check cache first
    if (_executionCache.containsKey(cacheKey)) {
      final cachedTime = _cacheTimestamps[cacheKey];
      if (cachedTime != null && DateTime.now().difference(cachedTime) < ttl) {
        return _executionCache[cacheKey]!;
      }
    }

    // Execute tool
    final result =
        await _mcpClient.executeTool(toolName, arguments, timeout: timeout);

    // Cache the result
    _executionCache[cacheKey] = result;
    _cacheTimestamps[cacheKey] = DateTime.now();

    return result;
  }

  /// 🧹 CLEAR CACHE: Clear all cached data
  void clearCache() {
    _toolCache.clear();
    _executionCache.clear();
    _cacheTimestamps.clear();
    print('🗑️  MCP cache cleared');
  }

  /// 📊 GET CACHE STATS: Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'toolCacheSize': _toolCache.length,
      'executionCacheSize': _executionCache.length,
      'cacheHits': _countCacheHits(),
      'cacheMisses': _executionCache.length - _countCacheHits(),
    };
  }

  /// 🔑 GENERATE EXECUTION CACHE KEY: Generate unique key for tool execution
  String _generateExecutionCacheKey(String toolName, String arguments) {
    try {
      // Normalize arguments to ensure consistent caching
      final argsMap = jsonDecode(arguments) as Map<String, dynamic>;
      final sortedArgs = Map.fromEntries(
          argsMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      final normalizedArgs = jsonEncode(sortedArgs);

      return '$toolName:$normalizedArgs';
    } catch (e) {
      // Fallback to raw arguments if JSON parsing fails
      return '$toolName:$arguments';
    }
  }

  /// 📈 COUNT CACHE HITS: Estimate cache hits based on timestamps
  int _countCacheHits() {
    final now = DateTime.now();
    return _cacheTimestamps.values
        .where((timestamp) => now.difference(timestamp) < Duration(minutes: 5))
        .length;
  }

  /// 🔄 DELEGATE METHODS: Pass through to underlying client
  Future<void> dispose() => _mcpClient.dispose();

  /// 🔢 TOOL COUNT: Get the number of tools available from the underlying client
  ///
  /// Returns the current count of tools available from the MCP client.
  /// This value may change if the client is reinitialized.
  int get toolCount => _mcpClient.toolCount;

  /// 🚪 DISPOSE: Clean up resources and dispose of the underlying MCP client
  ///
  /// Releases any resources held by the caching wrapper and underlying client.
  /// This should be called when the wrapper is no longer needed.

  List<Tool> get tools => _mcpClient.tools;
}

/// 🔧 CACHING MCP TOOL EXECUTOR: Caching version of McpToolExecutor
///
/// Wraps McpToolExecutor with caching capabilities
class CachingMcpToolExecutor implements ToolExecutor {
  final McpToolExecutor _delegate;
  final McpCachingWrapper _cachingWrapper;

  /// 🏗️ CONSTRUCTOR: Create new caching tool executor
  CachingMcpToolExecutor(McpClient mcpClient, Tool tool)
      : _delegate = McpToolExecutor(mcpClient, tool),
        _cachingWrapper = McpCachingWrapper(mcpClient);

  @override
  String get toolName => _delegate.toolName;

  @override
  String get toolDescription => _delegate.toolDescription;

  @override
  Map<String, dynamic> get toolParameters => _delegate.toolParameters;

  @override
  bool canExecute(ToolCall toolCall) => _delegate.canExecute(toolCall);

  @override
  Future<String> executeTool(ToolCall toolCall, {Duration? timeout}) async {
    // Determine if this tool call is cacheable
    final isCacheable = _isToolCacheable(toolCall);

    if (isCacheable) {
      return await _cachingWrapper.executeToolWithCache(
        toolCall.function.name,
        toolCall.function.arguments,
        cacheable: true,
        timeout: timeout,
      );
    } else {
      return await _delegate.executeTool(toolCall, timeout: timeout);
    }
  }

  @override
  Tool get asTool => _delegate.asTool;

  /// ✅ IS TOOL CACHEABLE: Determine if a tool call can be cached
  ///
  /// Some operations are not cacheable because they:
  /// - Modify state (write operations)
  /// - Return time-sensitive data
  /// - Have side effects
  bool _isToolCacheable(ToolCall toolCall) {
    final toolName = toolCall.function.name;

    // List of cacheable tools (read-only operations)
    const cacheableTools = {
      'read_text_file',
      'read_file',
      'list_directory',
      'directory_tree',
      'get_file_info',
      'search_files',
      'list_allowed_directories',
    };

    // List of non-cacheable tools (write operations or state changes)
    const nonCacheableTools = {
      'write_file',
      'edit_file',
      'create_directory',
      'move_file',
      'execute_terminal_command',
      'puppeteer_navigate',
      'puppeteer_get_inner_text',
    };

    if (nonCacheableTools.contains(toolName)) {
      return false;
    }

    if (cacheableTools.contains(toolName)) {
      return true;
    }

    // Default to non-cacheable for unknown tools
    return false;
  }

  /// 🧹 CLEAR CACHE: Clear the execution cache
  void clearCache() {
    _cachingWrapper.clearCache();
  }
}
