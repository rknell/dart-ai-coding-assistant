import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../../mcp/code_quality_mcp_server.dart';

/// 🧪 TEST: Code Quality MCP Server
///
/// Tests the Code Quality MCP Server functionality including:
/// - Server initialization 
/// - Lint analysis tools
/// - Error handling
/// - Output formatting
void main() {
  group('CodeQualityMCPServer', () {
    late CodeQualityMCPServer server;
    late Directory testDir;
    late File testFile;
    late File invalidDartFile;

    setUp(() async {
      // Initialize server with debug logging
      server = CodeQualityMCPServer(
        enableDebugLogging: true,
        executionTimeout: const Duration(seconds: 30),
      );

      // Create test directory and files
      testDir = Directory('test_code_quality_temp');
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
      testDir.createSync();

      // Create valid Dart file
      testFile = File(path.join(testDir.path, 'valid_test.dart'));
      testFile.writeAsStringSync('''
void main() {
  print('Hello, World!');
}
''');

      // Create invalid Dart file with linting issues
      invalidDartFile = File(path.join(testDir.path, 'invalid_test.dart'));
      invalidDartFile.writeAsStringSync('''
void main() {
  var unusedVariable = 'this will cause a warning';
  print('Hello World')  // Missing semicolon - error
}
''');

      await server.initializeServer();
    });

    tearDown(() async {
      // Clean up test files
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
      await server.shutdown();
    });

    test('🚀 should initialize with correct tools', () async {
      final tools = server.getAvailableTools();
      expect(tools, hasLength(2));
      
      final toolNames = tools.map((t) => t.name).toSet();
      expect(toolNames, contains('run_lint_analysis'));
      expect(toolNames, contains('quick_lint_check'));
    });

    test('🔍 should run lint analysis on valid code', () async {
      final result = await server.callTool('run_lint_analysis', {
        'path': testFile.path,
        'format': 'json'
      });

      expect(result.isError, isFalse);
      expect(result.content, hasLength(1));
      
      final content = result.content.first;
      expect(content.type, equals('text'));
      
      final responseData = jsonDecode(content.text!);
      expect(responseData['success'], isTrue);
      
      final data = responseData['data'] as Map<String, dynamic>;
      expect(data['analysis_path'], equals(testFile.path));
      expect(data['status'], equals('clean'));
      expect(data['total_issues'], equals(0));
      expect(data['error_count'], equals(0));
      expect(data['warning_count'], equals(0));
      expect(data.containsKey('execution_time_ms'), isTrue);
    });

    test('❌ should detect issues in invalid code', () async {
      final result = await server.callTool('run_lint_analysis', {
        'path': invalidDartFile.path,
        'format': 'json'
      });

      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final responseData = jsonDecode(content.text!);
      expect(responseData['success'], isTrue);
      
      final data = responseData['data'] as Map<String, dynamic>;
      expect(data['analysis_path'], equals(invalidDartFile.path));
      expect(data['status'], equals('issues_found'));
      expect(data['total_issues'], greaterThan(0));
      expect(data.containsKey('issues'), isTrue);
    });

    test('⚡ should perform quick lint check', () async {
      final result = await server.callTool('quick_lint_check', {
        'path': invalidDartFile.path
      });

      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final responseData = jsonDecode(content.text!);
      expect(responseData['success'], isTrue);
      
      final data = responseData['data'] as Map<String, dynamic>;
      expect(data['status'], equals('issues_found'));
      expect(data['has_errors'], isTrue);
      expect(data['issue_count'], greaterThan(0));
      expect(data.containsKey('summary'), isTrue);
    });

    test('📄 should format results as text', () async {
      final result = await server.callTool('run_lint_analysis', {
        'path': invalidDartFile.path,
        'format': 'text'
      });

      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final responseData = jsonDecode(content.text!);
      expect(responseData['success'], isTrue);
      
      final data = responseData['data'] as Map<String, dynamic>;
      expect(data['format'], equals('text'));
      expect(data.containsKey('formatted_output'), isTrue);
      
      final output = data['formatted_output'] as String;
      expect(output, contains('Code Quality Analysis Results'));
    });

    test('🚫 should handle non-existent path', () async {
      final result = await server.callTool('run_lint_analysis', {
        'path': '/non/existent/path'
      });

      expect(result.isError, isFalse); // MCPToolResult doesn't use isError the same way
      
      final content = result.content.first;
      final responseData = jsonDecode(content.text!);
      expect(responseData['success'], isFalse);
      expect(responseData['error'], contains('Path does not exist'));
    });

    test('⚙️ should use default parameters', () async {
      final result = await server.callTool('run_lint_analysis', {});

      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final responseData = jsonDecode(content.text!);
      
      if (responseData['success'] == true) {
        final data = responseData['data'] as Map<String, dynamic>;
        expect(data['analysis_path'], equals('.'));
      }
    });

    test('⏱️ should include execution timing', () async {
      final result = await server.callTool('run_lint_analysis', {
        'path': testFile.path
      });

      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final responseData = jsonDecode(content.text!);
      
      if (responseData['success'] == true) {
        final data = responseData['data'] as Map<String, dynamic>;
        expect(data.containsKey('execution_time_ms'), isTrue);
        expect(data['execution_time_ms'], isA<int>());
        expect(data['execution_time_ms'], greaterThan(0));
      }
    });

    test('🔧 should validate tool schema', () {
      final lintTool = server.getAvailableTools()
          .firstWhere((t) => t.name == 'run_lint_analysis');
      
      expect(lintTool.description, isNotEmpty);
      expect(lintTool.inputSchema.containsKey('type'), isTrue);
      expect(lintTool.inputSchema.containsKey('properties'), isTrue);
      
      final properties = lintTool.inputSchema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('path'), isTrue);
      expect(properties.containsKey('include_info'), isTrue);
      expect(properties.containsKey('format'), isTrue);
    });
  });

  group('CodeQualityMCPServer Integration', () {
    late CodeQualityMCPServer server;
    
    setUp(() async {
      server = CodeQualityMCPServer(
        enableDebugLogging: false,
        executionTimeout: const Duration(seconds: 10),
      );
      await server.initializeServer();
    });

    tearDown(() async {
      await server.shutdown();
    });

    test('🚦 should handle current directory analysis', () async {
      final result = await server.callTool('run_lint_analysis', {
        'path': '.',
        'format': 'json'
      });

      expect(result.isError, isFalse);
      
      final content = result.content.first;
      final responseData = jsonDecode(content.text!);
      
      // Should either succeed or fail gracefully
      if (responseData['success'] == true) {
        final data = responseData['data'] as Map<String, dynamic>;
        expect(data['analysis_path'], equals('.'));
        expect(data.containsKey('total_issues'), isTrue);
      } else {
        // If it fails, should have error message
        expect(responseData.containsKey('error'), isTrue);
      }
    });
  });
}