import 'dart:io';

import 'package:dart_ai_coding_assistant/cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// 🧪 TEST: Cache Manager functionality
/// 
/// Tests the caching system for file operations, directory listings,
/// and project analysis to ensure proper caching behavior.
void main() {
  group('CacheManager', () {
    late CacheManager cacheManager;
    late Directory testDir;
    late File testFile;
    
    setUp(() async {
      cacheManager = CacheManager();
      cacheManager.clearCache(); // Reset cache stats
      
      // Create test directory and file
      testDir = Directory('test_cache_dir');
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
      testDir.createSync();
      
      testFile = File(path.join(testDir.path, 'test.txt'));
      testFile.writeAsStringSync('Hello, World!\nLine 2\nLine 3');
    });

    tearDown(() async {
      // Clean up test directory
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
      
      // Clear cache between tests
      cacheManager.clearCache();
    });

    test('should cache file content reads', () async {
      final initialStats = cacheManager.getCacheStats();
      final initialHits = initialStats['hits'] as int;
      final initialMisses = initialStats['misses'] as int;
      
      // First read (should miss cache)
      final content1 = await cacheManager.readFileWithCache(testFile.path);
      expect(content1, 'Hello, World!\nLine 2\nLine 3');
      
      // Second read (should hit cache)
      final content2 = await cacheManager.readFileWithCache(testFile.path);
      expect(content2, content1);
      
      // Verify cache stats
      final stats = cacheManager.getCacheStats();
      expect(stats['hits'], initialHits + 1);
      expect(stats['misses'], initialMisses + 1);
    });

    test('should invalidate cache when file changes', () async {
      final initialStats = cacheManager.getCacheStats();
      final initialMisses = initialStats['misses'] as int;
      
      // First read
      await cacheManager.readFileWithCache(testFile.path);
      
      // Modify file
      testFile.writeAsStringSync('Modified content');
      
      // Second read should miss cache due to modification
      final content2 = await cacheManager.readFileWithCache(testFile.path);
      expect(content2, 'Modified content');
      
      final stats = cacheManager.getCacheStats();
      expect(stats['misses'], initialMisses + 2); // Both should be misses due to modification
    });

    test('should cache directory listings', () async {
      final initialStats = cacheManager.getCacheStats();
      final initialHits = initialStats['hits'] as int;
      final initialMisses = initialStats['misses'] as int;
      
      // First listing (should miss cache)
      final entries1 = await cacheManager.listDirectoryWithCache(testDir.path);
      expect(entries1, contains(testFile.path));
      
      // Second listing (should hit cache)
      final entries2 = await cacheManager.listDirectoryWithCache(testDir.path);
      expect(entries2, entries1);
      
      final stats = cacheManager.getCacheStats();
      expect(stats['hits'], initialHits + 1);
      expect(stats['misses'], initialMisses + 1);
    });

    test('should handle file head reads with caching', () async {
      // Read first 2 lines
      final content1 = await cacheManager.readFileWithCache(testFile.path, head: 2);
      expect(content1, 'Hello, World!\nLine 2');
      
      // Second read should hit cache
      final content2 = await cacheManager.readFileWithCache(testFile.path, head: 2);
      expect(content2, content1);
    });

    test('should handle file tail reads with caching', () async {
      // Read last 2 lines
      final content1 = await cacheManager.readFileWithCache(testFile.path, tail: 2);
      expect(content1, 'Line 2\nLine 3');
      
      // Second read should hit cache
      final content2 = await cacheManager.readFileWithCache(testFile.path, tail: 2);
      expect(content2, content1);
    });

    test('should generate different cache keys for head/tail operations', () async {
      // Read full file
      await cacheManager.readFileWithCache(testFile.path);
      
      // Read head
      await cacheManager.readFileWithCache(testFile.path, head: 2);
      
      // Read tail
      await cacheManager.readFileWithCache(testFile.path, tail: 2);
      
      final stats = cacheManager.getCacheStats();
      expect(stats['fileCacheSize'], 3); // Three different cache entries
      expect(stats['misses'], 3); // All should be misses
    });

    test('should handle non-existent files gracefully', () async {
      final nonExistentFile = File(path.join(testDir.path, 'nonexistent.txt'));
      
      expect(
        () async => await cacheManager.readFileWithCache(nonExistentFile.path),
        throwsA(isA<Exception>()),
      );
    });

    test('should handle non-existent directories gracefully', () async {
      final nonExistentDir = Directory(path.join(testDir.path, 'nonexistent'));
      
      expect(
        () async => await cacheManager.listDirectoryWithCache(nonExistentDir.path),
        throwsA(isA<Exception>()),
      );
    });

    test('should clear cache completely', () async {
      // Add some cache entries
      await cacheManager.readFileWithCache(testFile.path);
      await cacheManager.listDirectoryWithCache(testDir.path);
      
      // Verify cache has entries
      var stats = cacheManager.getCacheStats();
      expect(stats['fileCacheSize'], 1);
      expect(stats['directoryCacheSize'], 1);
      
      // Clear cache
      cacheManager.clearCache();
      
      // Verify cache is empty
      stats = cacheManager.getCacheStats();
      expect(stats['fileCacheSize'], 0);
      expect(stats['directoryCacheSize'], 0);
      expect(stats['invalidations'], greaterThan(0));
    });

    test('should calculate hit rate correctly', () async {
      final initialStats = cacheManager.getCacheStats();
      final initialHits = initialStats['hits'] as int;
      final initialMisses = initialStats['misses'] as int;
      
      // First read (miss)
      await cacheManager.readFileWithCache(testFile.path);
      
      // Second read (hit)
      await cacheManager.readFileWithCache(testFile.path);
      
      // Third read (hit)
      await cacheManager.readFileWithCache(testFile.path);
      
      final stats = cacheManager.getCacheStats();
      expect(stats['hits'], initialHits + 2);
      expect(stats['misses'], initialMisses + 1);
      
      // Calculate expected hit rate based on the additional operations we just performed
      final totalHits = initialHits + 2;
      final totalMisses = initialMisses + 1;
      final expectedHitRate = totalHits / (totalHits + totalMisses);
      expect(stats['hitRate'], closeTo(expectedHitRate, 0.001));
    });
  });
}