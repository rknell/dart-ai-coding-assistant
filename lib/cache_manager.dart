import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// 🗄️ CACHE MANAGER: KV Cache implementation for DeepSeek API cost optimization
/// 
/// Implements caching strategies according to DeepSeek API documentation:
/// https://api-docs.deepseek.com/guides/kv_cache
/// 
/// Caches expensive operations to reduce token usage and API costs:
/// - File content reads
/// - Directory listings  
/// - Project structure analysis
/// - MCP tool discovery
/// - Configuration files
///
/// 🎯 CACHING STRATEGY:
/// - File content: Cache with file modification time validation
/// - Directory structure: Cache with short TTL (5 minutes)
/// - Project analysis: Cache per session
/// - MCP tools: Cache until server restart
/// - Config files: Cache until file modification
class CacheManager {
  /// 🔒 SINGLETON: Single instance for global cache management
  static final CacheManager _instance = CacheManager._internal();
  
  /// 🏭 FACTORY: Get the singleton instance
  factory CacheManager() => _instance;
  
  /// 🔧 PRIVATE CONSTRUCTOR: Initialize the singleton
  CacheManager._internal();

  /// 📊 FILE CONTENT CACHE: Cache for file contents with modification validation
  final Map<String, _FileCacheEntry> _fileContentCache = {};
  
  /// 📁 DIRECTORY CACHE: Cache for directory listings with TTL
  final Map<String, _DirectoryCacheEntry> _directoryCache = {};
  
  /// 🛠️ PROJECT ANALYSIS CACHE: Cache for project analysis results
  final Map<String, dynamic> _projectAnalysisCache = {};
  
  /// 🔧 MCP TOOL CACHE: Cache for MCP tool discovery
  final Map<String, List<Map<String, dynamic>>> _mcpToolCache = {};
  
  /// ⚙️ CONFIG CACHE: Cache for configuration files
  final Map<String, _ConfigCacheEntry> _configCache = {};

  /// 📝 CACHE STATISTICS: Track cache performance
  int _hits = 0;
  int _misses = 0;
  int _invalidations = 0;

  /// 📖 READ FILE WITH CACHE: Read file content with caching
  /// 
  /// [filePath] - Path to the file to read
  /// [head] - Optional number of lines to read from start
  /// [tail] - Optional number of lines to read from end
  /// 
  /// Returns cached content if available and valid, otherwise reads from filesystem
  Future<String> readFileWithCache(String filePath, {int? head, int? tail}) async {
    final cacheKey = _generateFileCacheKey(filePath, head: head, tail: tail);
    
    // Check cache first
    final cachedEntry = _fileContentCache[cacheKey];
    if (cachedEntry != null && await _isFileCacheValid(cachedEntry, filePath)) {
      _hits++;
      return cachedEntry.content;
    }
    
    _misses++;
    
    // Read from filesystem
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found: $filePath');
    }
    
    String content;
    if (head != null) {
      content = await _readFileHead(file, head);
    } else if (tail != null) {
      content = await _readFileTail(file, tail);
    } else {
      content = await file.readAsString();
    }
    
    // Cache the result
    final stat = file.statSync();
    _fileContentCache[cacheKey] = _FileCacheEntry(
      content: content,
      filePath: filePath,
      lastModified: stat.modified,
      fileSize: stat.size,
    );
    
    return content;
  }

  /// 📁 LIST DIRECTORY WITH CACHE: List directory contents with caching
  /// 
  /// [dirPath] - Path to the directory to list
  /// [ttl] - Time-to-live for cache entry (default: 5 minutes)
  /// 
  /// Returns cached directory listing if available and valid
  Future<List<String>> listDirectoryWithCache(String dirPath, {Duration ttl = const Duration(minutes: 5)}) async {
    final cacheKey = dirPath;
    
    // Check cache first
    final cachedEntry = _directoryCache[cacheKey];
    if (cachedEntry != null && _isDirectoryCacheValid(cachedEntry, ttl)) {
      _hits++;
      return cachedEntry.entries;
    }
    
    _misses++;
    
    // Read from filesystem
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      throw Exception('Directory not found: $dirPath');
    }
    
    final entries = await dir.list().map((entry) => entry.path).toList();
    
    // Cache the result
    _directoryCache[cacheKey] = _DirectoryCacheEntry(
      entries: entries,
      cachedAt: DateTime.now(),
    );
    
    return entries;
  }

  /// 📊 GET DIRECTORY TREE WITH CACHE: Get recursive directory tree with caching
  /// 
  /// [dirPath] - Path to the directory to analyze
  /// [ttl] - Time-to-live for cache entry (default: 10 minutes)
  /// 
  /// Returns cached directory tree if available and valid
  Future<Map<String, dynamic>> getDirectoryTreeWithCache(String dirPath, {Duration ttl = const Duration(minutes: 10)}) async {
    final cacheKey = 'tree:$dirPath';
    
    // Check project analysis cache first
    if (_projectAnalysisCache.containsKey(cacheKey)) {
      final cachedData = _projectAnalysisCache[cacheKey];
      if (cachedData is Map<String, dynamic>) {
        final cachedTime = cachedData['_cachedAt'] as DateTime?;
        if (cachedTime != null && DateTime.now().difference(cachedTime) < ttl) {
          _hits++;
          
          // Remove cache metadata before returning
          final result = Map<String, dynamic>.from(cachedData);
          result.remove('_cachedAt');
          return result;
        }
      }
    }
    
    _misses++;
    
    // Generate directory tree (simplified implementation)
    final tree = await _generateDirectoryTree(dirPath);
    
    // Cache the result with timestamp
    final cacheData = Map<String, dynamic>.from(tree);
    cacheData['_cachedAt'] = DateTime.now();
    _projectAnalysisCache[cacheKey] = cacheData;
    
    return tree;
  }

  /// 🧹 CLEAR CACHE: Clear all cached data
  void clearCache() {
    _fileContentCache.clear();
    _directoryCache.clear();
    _projectAnalysisCache.clear();
    _mcpToolCache.clear();
    _configCache.clear();
    _invalidations += 5; // Count each cleared cache
    
    print('🗑️  All caches cleared');
  }

  /// 📊 GET CACHE STATS: Get cache performance statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'fileCacheSize': _fileContentCache.length,
      'directoryCacheSize': _directoryCache.length,
      'projectAnalysisCacheSize': _projectAnalysisCache.length,
      'mcpToolCacheSize': _mcpToolCache.length,
      'configCacheSize': _configCache.length,
      'hits': _hits,
      'misses': _misses,
      'hitRate': _hits / (_hits + _misses).clamp(0.001, double.infinity),
      'invalidations': _invalidations,
    };
  }

  /// 🔑 GENERATE FILE CACHE KEY: Generate unique cache key for file operations
  String _generateFileCacheKey(String filePath, {int? head, int? tail}) {
    final parts = [filePath];
    if (head != null) parts.add('head:$head');
    if (tail != null) parts.add('tail:$tail');
    return parts.join('|');
  }

  /// ✅ VALIDATE FILE CACHE: Check if cached file content is still valid
  Future<bool> _isFileCacheValid(_FileCacheEntry entry, String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;
      
      final stat = file.statSync();
      return stat.modified == entry.lastModified && stat.size == entry.fileSize;
    } catch (e) {
      return false;
    }
  }

  /// ✅ VALIDATE DIRECTORY CACHE: Check if cached directory listing is still valid
  bool _isDirectoryCacheValid(_DirectoryCacheEntry entry, Duration ttl) {
    return DateTime.now().difference(entry.cachedAt) < ttl;
  }

  /// 📖 READ FILE HEAD: Read first N lines of a file
  Future<String> _readFileHead(File file, int lineCount) async {
    final lines = await file.openRead()
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .take(lineCount)
        .toList();
    return lines.join('\n');
  }

  /// 📖 READ FILE TAIL: Read last N lines of a file
  Future<String> _readFileTail(File file, int lineCount) async {
    final content = await file.readAsString();
    final lines = content.split('\n');
    final start = lines.length - lineCount;
    return lines.sublist(start.clamp(0, lines.length)).join('\n');
  }

  /// 🌳 GENERATE DIRECTORY TREE: Generate directory tree structure
  Future<Map<String, dynamic>> _generateDirectoryTree(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return {'error': 'Directory not found: $dirPath'};
    }
    
    final result = <String, dynamic>{};
    
    await for (final entity in dir.list(recursive: true)) {
      final relativePath = path.relative(entity.path, from: dirPath);
      final parts = relativePath.split(path.separator);
      
      var current = result;
      for (var i = 0; i < parts.length - 1; i++) {
        final part = parts[i];
        if (!current.containsKey(part)) {
          current[part] = <String, dynamic>{};
        }
        current = current[part] as Map<String, dynamic>;
      }
      
      final fileName = parts.last;
      current[fileName] = {
        'type': entity is File ? 'file' : 'directory',
        'path': entity.path,
      };
    }
    
    return result;
  }
}

/// 📝 FILE CACHE ENTRY: Cache entry for file content
class _FileCacheEntry {
  final String content;
  final String filePath;
  final DateTime lastModified;
  final int fileSize;
  
  _FileCacheEntry({
    required this.content,
    required this.filePath,
    required this.lastModified,
    required this.fileSize,
  });
}

/// 📁 DIRECTORY CACHE ENTRY: Cache entry for directory listing
class _DirectoryCacheEntry {
  final List<String> entries;
  final DateTime cachedAt;
  
  _DirectoryCacheEntry({
    required this.entries,
    required this.cachedAt,
  });
}

/// ⚙️ CONFIG CACHE ENTRY: Cache entry for configuration files
class _ConfigCacheEntry {
  final dynamic configData;
  final DateTime cachedAt;
  final DateTime fileModified;
  
  _ConfigCacheEntry({
    required this.configData,
    required this.cachedAt,
    required this.fileModified,
  });
}

/// 🌐 GLOBAL CACHE INSTANCE: Easy access to cache manager
final cacheManager = CacheManager();