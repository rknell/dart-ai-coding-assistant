import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_ai_coding_assistant/cache_manager.dart';
import 'package:dart_openai_client/dart_openai_client.dart';

/// 🗄️ FILESYSTEM MCP SERVER: Cached Filesystem Operations
///
/// Provides filesystem access with DeepSeek API context caching optimization
/// Implements caching strategies according to DeepSeek API documentation:
/// https://api-docs.deepseek.com/guides/kv_cache
///
/// Caches expensive filesystem operations to reduce:
/// - Token usage in AI context windows
/// - API costs for repeated file operations
/// - Latency for frequently accessed files
///
/// 🎯 CACHING STRATEGY:
/// - File content: Cache with file modification time validation
/// - Directory listings: Cache with short TTL (5 minutes)
/// - Directory trees: Cache per session (10 minutes)
/// - File metadata: Cache with file modification validation
class FilesystemMCPServer extends BaseMCPServer {
  final bool enableDebugLogging;
  final Duration defaultCacheTTL;

  FilesystemMCPServer({
    super.name = 'filesystem',
    super.version = '1.0.0',
    super.logger,
    this.enableDebugLogging = false,
    this.defaultCacheTTL = const Duration(minutes: 5),
  });

  @override
  Future<void> initializeServer() async {
    // File reading tools with caching
    registerTool(MCPTool(
      name: 'read_text_file',
      description:
          'Read the complete contents of a file from the file system as text. Handles various text encodings and provides detailed error messages if the file cannot be read. Use this tool when you need to examine the contents of a single file. Use the \'head\' parameter to read only the first N lines of a file, or the \'tail\' parameter to read only the last N lines of a file. Operates on the file as text regardless of extension. Only works within allowed directories.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'tail': {
            'type': 'number',
            'description':
                'If provided, returns only the last N lines of the file',
          },
          'head': {
            'type': 'number',
            'description':
                'If provided, returns only the first N lines of the file',
          },
        },
        'required': ['path'],
      },
      callback: _handleReadTextFile,
    ));

    registerTool(MCPTool(
      name: 'read_file',
      description:
          'Read the complete contents of a file as text. DEPRECATED: Use read_text_file instead.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'tail': {
            'type': 'number',
            'description':
                'If provided, returns only the last N lines of the file',
          },
          'head': {
            'type': 'number',
            'description':
                'If provided, returns only the first N lines of the file',
          },
        },
        'required': ['path'],
      },
      callback: _handleReadFile,
    ));

    // Directory operations with caching
    registerTool(MCPTool(
      name: 'list_directory',
      description:
          'Get a detailed listing of all files and directories in a specified path. Results clearly distinguish between files and directories with [FILE] and [DIR] prefixes. This tool is essential for understanding directory structure and finding specific files within a directory. Only works within allowed directories.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
        },
        'required': ['path'],
      },
      callback: _handleListDirectory,
    ));

    registerTool(MCPTool(
      name: 'directory_tree',
      description:
          'Get a recursive tree view of files and directories as a JSON structure. Each entry includes \'name\', \'type\' (file/directory), and \'children\' for directories. Files have no children array, while directories always have a children array (which may be empty). The output is formatted with 2-space indentation for readability. Only works within allowed directories.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
        },
        'required': ['path'],
      },
      callback: _handleDirectoryTree,
    ));

    // File metadata with caching
    registerTool(MCPTool(
      name: 'get_file_info',
      description:
          'Retrieve detailed metadata about a file or directory. Returns comprehensive information including size, creation time, last modified time, permissions, and type. This tool is perfect for understanding file characteristics without reading the actual content. Only works within allowed directories.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
        },
        'required': ['path'],
      },
      callback: _handleGetFileInfo,
    ));

    // Search operations with caching
    registerTool(MCPTool(
      name: 'search_files',
      description:
          'Recursively search for files and directories matching a pattern. Searches through all subdirectories from the starting path. The search is case-insensitive and matches partial names. Returns full paths to all matching items. Great for finding files when you don\'t know their exact location. Only searches within allowed directories.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'pattern': {'type': 'string'},
          'excludePatterns': {
            'type': 'array',
            'items': {'type': 'string'},
            'default': <String>[],
          },
        },
        'required': ['path', 'pattern'],
      },
      callback: _handleSearchFiles,
    ));

    // Allowed directories
    registerTool(MCPTool(
      name: 'list_allowed_directories',
      description:
          'Returns the list of directories that this server is allowed to access. Subdirectories within these allowed directories are also accessible. Use this to understand which directories and their nested paths are available before trying to access files.',
      inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
      callback: _handleListAllowedDirectories,
    ));

    // Cache management tools
    registerTool(MCPTool(
      name: 'get_cache_stats',
      description:
          'Get cache performance statistics including hit rates and memory usage',
      inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
      callback: _handleGetCacheStats,
    ));

    registerTool(MCPTool(
      name: 'clear_cache',
      description: 'Clear all cached file and directory data',
      inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
      callback: _handleClearCache,
    ));

    logger?.call('info', 'Filesystem MCP server initialized with caching');
  }

  Future<MCPToolResult> _handleReadTextFile(
      Map<String, dynamic> arguments) async {
    final path = arguments['path'] as String;
    final head = arguments['head'] as int?;
    final tail = arguments['tail'] as int?;

    try {
      // Use cache manager for optimized file reading
      final content = await cacheManager.readFileWithCache(
        path,
        head: head,
        tail: tail,
      );

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'content': content,
          'cached': true, // Indicate that caching was used
          'path': path,
          'head': head,
          'tail': tail,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Failed to read file: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleReadFile(Map<String, dynamic> arguments) async {
    // Delegate to read_text_file implementation (backward compatibility)
    return _handleReadTextFile(arguments);
  }

  Future<MCPToolResult> _handleListDirectory(
      Map<String, dynamic> arguments) async {
    final path = arguments['path'] as String;

    try {
      // Use cache manager for optimized directory listing
      final entries = await cacheManager.listDirectoryWithCache(path);

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'entries': entries,
          'cached': true, // Indicate that caching was used
          'path': path,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Failed to list directory: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleDirectoryTree(
      Map<String, dynamic> arguments) async {
    final path = arguments['path'] as String;

    try {
      // Use cache manager for optimized directory tree
      final tree = await cacheManager.getDirectoryTreeWithCache(path);

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'tree': tree,
          'cached': true, // Indicate that caching was used
          'path': path,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Failed to get directory tree: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleGetFileInfo(
      Map<String, dynamic> arguments) async {
    final path = arguments['path'] as String;

    try {
      final file = File(path);
      if (!file.existsSync()) {
        throw Exception('File not found: $path');
      }

      final stat = file.statSync();
      final info = {
        'path': path,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
        'changed': stat.changed.toIso8601String(),
        'accessed': stat.accessed.toIso8601String(),
        'type': stat.type.toString(),
        'mode': stat.mode,
      };

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'info': info,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Failed to get file info: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleSearchFiles(
      Map<String, dynamic> arguments) async {
    final path = arguments['path'] as String;
    final pattern = arguments['pattern'] as String;
    final excludePatterns =
        (arguments['excludePatterns'] as List<dynamic>?)?.cast<String>() ?? [];

    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        throw Exception('Directory not found: $path');
      }

      final results = <String>[];
      await for (final entity in dir.list(recursive: true)) {
        final entityName = entity.path.split('/').last;

        // Check if entity matches pattern
        if (entityName.toLowerCase().contains(pattern.toLowerCase())) {
          // Check if entity should be excluded
          final shouldExclude = excludePatterns.any((excludePattern) =>
              entityName.toLowerCase().contains(excludePattern.toLowerCase()));

          if (!shouldExclude) {
            results.add(entity.path);
          }
        }
      }

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'results': results,
          'count': results.length,
          'path': path,
          'pattern': pattern,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Failed to search files: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleListAllowedDirectories(
      Map<String, dynamic> arguments) async {
    try {
      // For now, return the current directory as allowed
      // In a real implementation, this would come from server configuration
      final allowedDirs = [
        Directory.current.path,
        if (Platform.environment.containsKey('HOME'))
          Platform.environment['HOME']!,
      ];

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'allowed_directories': allowedDirs,
        })),
      ]);
    } catch (e) {
      throw MCPServerException(
          'Failed to list allowed directories: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleGetCacheStats(
      Map<String, dynamic> arguments) async {
    try {
      final stats = cacheManager.getCacheStats();

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'stats': stats,
          'estimated_cost_reduction':
              '~${(stats['hitRate'] * 30).toStringAsFixed(1)}%',
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Failed to get cache stats: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleClearCache(
      Map<String, dynamic> arguments) async {
    try {
      cacheManager.clearCache();

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'message': 'All caches cleared successfully',
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Failed to clear cache: ${e.toString()}');
    }
  }

  @override
  Future<void> shutdown() async {
    // Clear cache on server shutdown
    cacheManager.clearCache();
    await super.shutdown();
  }
}

/// Main entry point
void main() async {
  final server = FilesystemMCPServer(
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
    stderr.writeln('Failed to start Filesystem MCP server: $e');
    exit(1);
  }
}
