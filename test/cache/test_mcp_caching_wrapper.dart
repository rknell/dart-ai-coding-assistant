import 'package:test/test.dart';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:dart_openai_client/src/mcp_client.dart';
import 'package:dart_ai_coding_assistant/mcp_caching_wrapper.dart';
import 'package:dart_openai_client/src/tool.dart';

/// 🧪 TEST: MCP Caching Wrapper functionality
/// 
/// Tests the caching wrapper for MCP tool operations to ensure
/// proper caching behavior and cost reduction.
void main() {
  group('McpCachingWrapper', () {
    late MockMcpClient mockClient;
    late McpCachingWrapper cachingWrapper;
    
    setUp(() {
      mockClient = MockMcpClient();
      cachingWrapper = McpCachingWrapper(mockClient);
    });

    tearDown(() {
      cachingWrapper.clearCache();
    });

    test('should cache tool execution results', () async {
      // First execution (should call underlying client)
      final result1 = await cachingWrapper.executeToolWithCache(
        'test_tool', 
        '{"param": "value"}',
        cacheable: true,
      );
      
      expect(result1, 'execution_result');
      expect(mockClient.executeCallCount, 1);
      
      // Second execution with same parameters (should hit cache)
      final result2 = await cachingWrapper.executeToolWithCache(
        'test_tool', 
        '{"param": "value"}',
        cacheable: true,
      );
      
      expect(result2, 'execution_result');
      expect(mockClient.executeCallCount, 1); // Should not increase
    });

    test('should not cache non-cacheable operations', () async {
      // Execute with cacheable=false
      final result1 = await cachingWrapper.executeToolWithCache(
        'test_tool', 
        '{"param": "value"}',
        cacheable: false,
      );
      
      expect(mockClient.executeCallCount, 1);
      
      // Execute again with cacheable=false
      final result2 = await cachingWrapper.executeToolWithCache(
        'test_tool', 
        '{"param": "value"}',
        cacheable: false,
      );
      
      expect(mockClient.executeCallCount, 2); // Should increase
    });

    test('should respect cache TTL', () async {
      // First execution
      await cachingWrapper.executeToolWithCache(
        'test_tool', 
        '{"param": "value"}',
        cacheable: true,
        ttl: Duration(milliseconds: 100), // Very short TTL
      );
      
      expect(mockClient.executeCallCount, 1);
      
      // Wait for TTL to expire
      await Future.delayed(Duration(milliseconds: 150));
      
      // Second execution should miss cache
      await cachingWrapper.executeToolWithCache(
        'test_tool', 
        '{"param": "value"}',
        cacheable: true,
        ttl: Duration(milliseconds: 100),
      );
      
      expect(mockClient.executeCallCount, 2); // Should increase
    });

    test('should generate consistent cache keys', () async {
      // Different argument formats should generate same cache key
      const args1 = '{"param": "value", "another": "test"}';
      const args2 = '{"another": "test", "param": "value"}'; // Different order
      
      // First execution
      await cachingWrapper.executeToolWithCache('test_tool', args1, cacheable: true);
      
      // Second execution with differently ordered but same arguments
      await cachingWrapper.executeToolWithCache('test_tool', args2, cacheable: true);
      
      // Should hit cache (only 1 execution call)
      expect(mockClient.executeCallCount, 1);
    });

    test('should handle JSON parsing errors gracefully', () async {
      // Invalid JSON should still work (fallback to raw arguments)
      const invalidJson = 'not valid json';
      
      await cachingWrapper.executeToolWithCache('test_tool', invalidJson, cacheable: true);
      
      // Should still execute
      expect(mockClient.executeCallCount, 1);
    });

    test('should clear cache properly', () async {
      // Add some cache entries
      await cachingWrapper.executeToolWithCache('tool1', '{"a": 1}', cacheable: true);
      await cachingWrapper.executeToolWithCache('tool2', '{"b": 2}', cacheable: true);
      
      // Verify cache has entries
      final stats = cachingWrapper.getCacheStats();
      expect(stats['executionCacheSize'], 2);
      
      // Clear cache
      cachingWrapper.clearCache();
      
      // Verify cache is empty
      final statsAfterClear = cachingWrapper.getCacheStats();
      expect(statsAfterClear['executionCacheSize'], 0);
    });

    test('should delegate tool count and tools properties', () {
      expect(cachingWrapper.toolCount, mockClient.toolCount);
      expect(cachingWrapper.tools, mockClient.tools);
    });
  });

  group('CachingMcpToolExecutor', () {
    late MockMcpClient mockClient;
    late Tool testTool;
    late CachingMcpToolExecutor cachingExecutor;
    
    setUp(() {
      mockClient = MockMcpClient();
      testTool = Tool(
        function: FunctionObject(
          name: 'read_text_file',
          description: 'Read text file',
          parameters: {
            'type': 'object',
            'properties': {'path': {'type': 'string'}},
            'required': ['path']
          },
        ),
      );
      cachingExecutor = CachingMcpToolExecutor(mockClient, testTool);
    });

    tearDown(() {
      cachingExecutor.clearCache();
    });

    test('should identify cacheable tools correctly', () {
      // Cacheable tools
      final cacheableCall = ToolCall(
        id: 'test',
        type: 'function',
        function: ToolCallFunction(
          name: 'read_text_file',
          arguments: '{"path": "test.txt"}',
        ),
      );
      
      expect(cachingExecutor.canExecute(cacheableCall), isTrue);
      
      // Non-cacheable tools
      final nonCacheableCall = ToolCall(
        id: 'test',
        type: 'function',
        function: ToolCallFunction(
          name: 'write_file',
          arguments: '{"path": "test.txt", "content": "data"}',
        ),
      );
      
      // Note: This executor only handles read_text_file, so canExecute should return false
      expect(cachingExecutor.canExecute(nonCacheableCall), isFalse);
    });

    test('should return correct tool properties', () {
      expect(cachingExecutor.toolName, 'read_text_file');
      expect(cachingExecutor.toolDescription, 'Read text file');
      expect(cachingExecutor.toolParameters, isMap);
      expect(cachingExecutor.asTool, isA<Tool>());
    });
  });
}

/// 🎭 MOCK: MCP Client for testing
class MockMcpClient extends McpClient {
  int executeCallCount = 0;
  
  MockMcpClient() : super(McpServerConfig(command: 'mock', args: []));
  
  @override
  Future<String> executeTool(String toolName, String arguments, {Duration? timeout}) async {
    executeCallCount++;
    return 'execution_result';
  }
  
  @override
  List<Tool> get tools => [
    Tool(
      function: FunctionObject(
        name: 'test_tool',
        description: 'Test tool',
        parameters: {'type': 'object'},
      ),
    )
  ];
  
  @override
  int get toolCount => 1;
}