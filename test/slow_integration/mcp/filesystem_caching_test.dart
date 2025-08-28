import 'dart:io';

import 'package:dart_ai_coding_assistant/cache_manager.dart';
import 'package:test/test.dart';

void main() {
  group('CacheManager Tests', () {
    late CacheManager cacheManager;
    late Directory testDir;
    late File testFile;
    
    setUp(() async {
      cacheManager = CacheManager();
      testDir = await Directory.systemTemp.createTemp('cache_test');
      testFile = File('${testDir.path}/test.txt');
      await testFile.writeAsString('Hello, World!\\nLine 2\\nLine 3');
    });

    tearDown(() async {
      cacheManager.clearCache();
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('File content caching', () async {
      await cacheManager.readFileWithCache(testFile.path);
      final content2 = await cacheManager.readFileWithCache(testFile.path);
      expect(content2, contains('Hello, World!'));
      final stats = cacheManager.getCacheStats();
      expect(stats['hits'], greaterThanOrEqualTo(1));
    });
  });
}
