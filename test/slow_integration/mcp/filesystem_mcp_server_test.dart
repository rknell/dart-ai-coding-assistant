import "dart:convert";
import 'dart:io';
import 'package:test/test.dart';
import '../../../mcp/mcp_server_filesystem.dart';

/// 🧪 TEST: Filesystem MCP Server with Caching
/// 
/// Tests the Filesystem MCP server to ensure it properly uses caching
/// and returns cache status in responses.
void main() {
  group('FilesystemMCPServer', () {
    late FilesystemMCPServer server;
    late Directory testDir;
    late File testFile;
    
    setUp(() async {
      server = FilesystemMCPServer();
      await server.initializeServer();
      
      // Create test directory and file
      testDir = Directory('test_fs_mcp_dir');
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
      testDir.createSync();
      
      testFile = File('test_fs_mcp_dir/test.txt');
      testFile.writeAsStringSync('Hello, MCP Server!\\nLine 2\\nLine 3');
    });

    tearDown(() async {
      // Clean up test directory
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
      
      // Clear server cache
      await server.shutdown();
    });

    test('should register filesystem tools', () {
      final tools = server.getAvailableTools();
      final toolNames = tools.map((t) => t.name).toList();
      
      expect(toolNames, contains('read_text_file'));
      expect(toolNames, contains('list_directory'));
      expect(toolNames, contains('directory_tree'));
      expect(toolNames, contains('get_cache_stats'));
      expect(toolNames, contains('clear_cache'));
    });

    test('should handle read_text_file with caching', () async {
      final result = await server.callTool('read_text_file', {
        'path': testFile.path,
      });
      
      expect(result.isError, isFalse);
      expect(result.content, hasLength(1));
      
      final response = jsonDecode(result.content.first.text!);
      expect(response['success'], isTrue);
      expect(response['content'], contains('Hello, MCP Server!'));
      expect(response['cached'], isTrue); // Should indicate caching was used
    });

    test('should handle list_directory with caching', () async {
      final result = await server.callTool('list_directory', {
        'path': testDir.path,
      });
      
      expect(result.isError, isFalse);
      expect(result.content, hasLength(1));
      
      final response = jsonDecode(result.content.first.text!);
      expect(response['success'], isTrue);
      expect(response['entries'], isList);
      expect(response['cached'], isTrue); // Should indicate caching was used
    });

    test('should provide cache statistics', () async {
      // First, perform some operations to populate cache
      await server.callTool('read_text_file', {'path': testFile.path});
      await server.callTool('list_directory', {'path': testDir.path});
      
      // Then get cache stats
      final result = await server.callTool('get_cache_stats', {});
      
      expect(result.isError, isFalse);
      expect(result.content, hasLength(1));
      
      final response = jsonDecode(result.content.first.text!);
      expect(response['success'], isTrue);
      expect(response['stats'], isMap);
      expect(response['stats']['hits'], greaterThanOrEqualTo(0));
      expect(response['stats']['misses'], greaterThanOrEqualTo(0));
    });

    test('should clear cache properly', () async {
      // Populate cache
      await server.callTool('read_text_file', {'path': testFile.path});
      
      // Clear cache
      final result = await server.callTool('clear_cache', {});
      
      expect(result.isError, isFalse);
      expect(result.content, hasLength(1));
      
      final response = jsonDecode(result.content.first.text!);
      expect(response['success'], isTrue);
      expect(response['message'], contains('cleared'));
    });
  });
}
