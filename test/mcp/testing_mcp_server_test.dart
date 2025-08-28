import 'dart:convert';

import 'package:test/test.dart';

// Import the server we want to test
import '../../mcp/mcp_server_testing.dart';

void main() {
  group('TestingMCPServer', () {
    late TestingMCPServer server;

    setUp(() {
      server = TestingMCPServer(
        logger: (level, message, [data]) {
          // Capture logs for testing
          if (level == 'error') {
            print('ERROR: $message');
          }
        },
      );
    });

    tearDown(() async {
      await server.shutdown();
    });

    test('should initialize with correct tools', () async {
      await server.initializeServer();
      
      final tools = server.getAvailableTools();
      expect(tools, hasLength(5));
      
      final toolNames = tools.map((t) => t.name).toList();
      expect(toolNames, contains('generate_unit_tests'));
      expect(toolNames, contains('execute_test_suite'));
      expect(toolNames, contains('generate_coverage_report'));
      expect(toolNames, contains('create_mock_data'));
      expect(toolNames, contains('run_performance_tests'));
    });

    test('generate_unit_tests tool should return structured response', () async {
      await server.initializeServer();
      
      final result = await server.callTool('generate_unit_tests', {
        'target': '.',
        'framework': 'test',
        'coverage': 80,
      });
      
      expect(result.isError, isFalse);
      expect(result.content, hasLength(1));
      
      final content = result.content.first;
      expect(content.type, 'text');
      
      final data = jsonDecode(content.text!) as Map<String, dynamic>;
      expect(data['success'], isTrue);
      expect(data['framework'], 'test');
      expect(data['target'], '.');
      expect(data['generated_tests'], isNotNull);
    });

    test('execute_test_suite tool should handle test execution', () async {
      await server.initializeServer();
      
      final result = await server.callTool('execute_test_suite', {
        'target': 'test/',
        'concurrency': 2,
        'timeout': 10,
        'verbose': false,
      });
      
      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final data = jsonDecode(content.text!) as Map<String, dynamic>;
      
      expect(data['success'], isTrue);
      expect(data['target'], 'test/');
      expect(data['concurrency'], 2);
      expect(data['total_tests'], isNotNull);
    });

    test('generate_coverage_report tool should support multiple formats', () async {
      await server.initializeServer();
      
      final result = await server.callTool('generate_coverage_report', {
        'format': 'console',
        'output_dir': 'coverage_test/',
        'min_coverage': 70,
      });
      
      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final data = jsonDecode(content.text!) as Map<String, dynamic>;
      
      expect(data['success'], isTrue);
      expect(data['format'], 'console');
      expect(data['output_directory'], 'coverage_test/');
      expect(data['total_coverage'], isNotNull);
    });

    test('create_mock_data tool should generate mock data', () async {
      await server.initializeServer();
      
      final result = await server.callTool('create_mock_data', {
        'type': 'user',
        'count': 3,
        'variations': 2,
      });
      
      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final data = jsonDecode(content.text!) as Map<String, dynamic>;
      
      expect(data['success'], isTrue);
      expect(data['type'], 'user');
      expect(data['count'], 3);
      expect(data['variations'], 2);
      expect(data['mock_data'], isList);
      expect(data['mock_data'], hasLength(3));
    });

    test('run_performance_tests tool should handle performance benchmarks', () async {
      await server.initializeServer();
      
      final result = await server.callTool('run_performance_tests', {
        'target': 'test/',
        'iterations': 5,
        'warmup': 1,
        'report_format': 'json',
      });
      
      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final data = jsonDecode(content.text!) as Map<String, dynamic>;
      
      expect(data['success'], isTrue);
      expect(data['target'], 'test/');
      expect(data['iterations'], 5);
      expect(data['warmup'], 1);
      expect(data['report_format'], 'json');
      expect(data['average_time_ms'], isNotNull);
    });

    test('should handle errors gracefully', () async {
      await server.initializeServer();
      
      // Test with invalid parameters
      final result = await server.callTool('generate_unit_tests', {
        'target': '/nonexistent/path',
      });
      
      // The tool should handle errors and not crash
      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final data = jsonDecode(content.text!) as Map<String, dynamic>;
      
      expect(data['success'], isTrue);
    });

    test('mock data generation should create varied data', () async {
      await server.initializeServer();
      
      // Test different types of mock data
      final types = ['string', 'int', 'bool', 'user', 'product'];
      
      for (final type in types) {
        final result = await server.callTool('create_mock_data', {
          'type': type,
          'count': 2,
          'variations': 2,
        });
        
        expect(result.isError, isFalse);
        
        final content = result.content.first;
        final data = jsonDecode(content.text!) as Map<String, dynamic>;
        
        expect(data['success'], isTrue);
        expect(data['mock_data'], hasLength(2));
        
        // Verify that mock data has the expected structure
        final mockData = data['mock_data'] as List<dynamic>;
        for (final item in mockData) {
          expect(item, isMap);
          final mapItem = item as Map<String, dynamic>;
          expect(mapItem, contains('id'));
          expect(mapItem, contains('name'));
        }
      }
    });

    test('coverage report should handle different output formats', () async {
      await server.initializeServer();
      
      final formats = ['html', 'json', 'lcov', 'console'];
      
      for (final format in formats) {
        final result = await server.callTool('generate_coverage_report', {
          'format': format,
          'output_dir': 'coverage_$format/',
        });
        
        expect(result.isError, isFalse);
        
        final content = result.content.first;
        final data = jsonDecode(content.text!) as Map<String, dynamic>;
        
        expect(data['success'], isTrue);
        expect(data['format'], format);
        expect(data['report_generated'], isTrue);
      }
    });

    test('performance tests should calculate statistics correctly', () async {
      await server.initializeServer();
      
      // Test with small iteration count
      final result = await server.callTool('run_performance_tests', {
        'target': 'test/',
        'iterations': 3,
        'warmup': 0,
        'report_format': 'none',
      });
      
      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final data = jsonDecode(content.text!) as Map<String, dynamic>;
      
      expect(data['success'], isTrue);
      expect(data['iterations'], 3);
      expect(data['average_time_ms'], isNotNull);
      expect(data['min_time_ms'], isNotNull);
      expect(data['max_time_ms'], isNotNull);
      expect(data['standard_deviation'], isNotNull);
    });

    test('should handle concurrent tool calls', () async {
      await server.initializeServer();
      
      // Test multiple concurrent tool calls
      final futures = [
        server.callTool('create_mock_data', {'type': 'user', 'count': 1}),
        server.callTool('create_mock_data', {'type': 'product', 'count': 1}),
        server.callTool('generate_coverage_report', {'format': 'console'}),
      ];
      
      final results = await Future.wait(futures);
      
      for (final result in results) {
        expect(result.isError, isFalse);
        expect(result.content, hasLength(1));
        
        final content = result.content.first;
        final data = jsonDecode(content.text!) as Map<String, dynamic>;
        expect(data['success'], isTrue);
      }
    });
  });

  group('TestingMCPServer Utilities', () {
    late TestingMCPServer server;

    setUp(() {
      server = TestingMCPServer();
    });

    test('generateMockString should create varied strings', () {
      final results = <String>[];
      for (var i = 0; i < 10; i++) {
        results.add(server.generateMockString(i));
      }
      
      // Should generate different strings for different variations
      expect(results.toSet(), hasLength(10));
      expect(results.every((s) => s.isNotEmpty), isTrue);
    });

    test('generateMockInt should create integers', () {
      final results = <int>[];
      for (var i = 0; i < 5; i++) {
        results.add(server.generateMockInt(i));
      }
      
      expect(results, equals([100, 200, 300, 400, 500]));
    });

    test('generateMockBool should alternate values', () {
      final results = <bool>[];
      for (var i = 0; i < 4; i++) {
        results.add(server.generateMockBool(i));
      }
      
      expect(results, equals([true, false, true, false]));
    });

    test('generateMockDateTime should create valid dates', () {
      final results = <String>[];
      for (var i = 0; i < 3; i++) {
        results.add(server.generateMockDateTime(i));
      }
      
      // Should generate valid ISO 8601 dates
      for (final dateStr in results) {
        expect(() => DateTime.parse(dateStr), returnsNormally);
      }
      
      // Dates should be different
      expect(results.toSet(), hasLength(3));
    });

    test('parseTestResults should handle various output formats', () {
      const testOutput = '''
+10 -2 ~1: Some tests failed
Elapsed time: 0:00:12.345678
All tests passed!
''';

      final results = server.parseTestResults(testOutput, 0);
      
      expect(results['total'], 13); // 10 + 2 + 1
      expect(results['passed'], 10);
      expect(results['failed'], 2);
      expect(results['skipped'], 1);
      expect(results['duration'], '0:00:12.345678');
    });

    test('calculateStatistics should compute correct values', () {
      final times = [100, 200, 300, 400, 500]; // microseconds
      final memory = [1024, 2048, 3072]; // bytes
      
      final stats = server.calculateStatistics(times, memory);
      
      expect(stats['average_time'], 300.0);
      expect(stats['min_time'], 100);
      expect(stats['max_time'], 500);
      expect(stats['std_dev'], closeTo(141.42, 0.01));
      expect(stats['memory_usage'], 2048.0);
      expect(stats['memory_mb'], closeTo(0.00195, 0.00001));
      expect(stats['times_ms'], equals([0.1, 0.2, 0.3, 0.4, 0.5]));
    });
  });
}