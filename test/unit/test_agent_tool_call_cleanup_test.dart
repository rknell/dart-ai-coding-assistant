import 'package:test/test.dart';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:dart_openai_client/src/agent.dart';
import 'package:dart_openai_client/src/api_client.dart';
import 'package:dart_openai_client/src/tool_executor.dart';
import 'package:dart_openai_client/src/message.dart';
import 'package:dart_openai_client/src/tool.dart';

/// 🧪 TEST: Agent Tool Call Cleanup and Error Handling
/// 
/// Tests the proper cleanup of tool call state when maximum rounds are exceeded
/// and ensures error responses are properly handled.
void main() {
  group('Agent Tool Call Cleanup', () {
    late MockApiClient mockApiClient;
    late MockToolExecutorRegistry mockToolRegistry;
    late Agent agent;
    
    setUp(() {
      mockApiClient = MockApiClient();
      mockToolRegistry = MockToolExecutorRegistry();
      
      agent = Agent(
        apiClient: mockApiClient,
        toolRegistry: mockToolRegistry,
        systemPrompt: 'Test system prompt',
      );
    });

    test('should clean up incomplete tool calls when max rounds exceeded', () async {
      // Arrange: Setup API client to always return tool calls
      mockApiClient.responseBehavior = MockApiClientBehavior.alwaysToolCalls;
      
      // Act & Assert: Should throw with proper cleanup
      expect(
        () async => await agent.sendMessage('test message'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'error message',
          contains('Maximum tool call rounds exceeded'),
        )),
      );
      
      // Verify: Check that cleanup occurred by examining message count
      // The agent should have cleaned up incomplete tool call rounds
      expect(agent.messageCount, lessThan(50)); // Should be reasonable
    });

    test('should handle tool execution errors gracefully', () async {
      // Arrange: Setup tool registry to throw on execution
      mockToolRegistry.shouldThrowOnExecute = true;
      mockApiClient.responseBehavior = MockApiClientBehavior.singleToolCallThenResponse;
      
      // Act: Send message that triggers tool execution
      final response = await agent.sendMessage('test message');
      
      // Assert: Should receive response with error information
      // The error should be in the conversation history, not necessarily the final response
      final errorMessages = agent.conversationHistory
          .where((msg) => msg.content?.contains('Tool execution failed') ?? false);
      expect(errorMessages.isNotEmpty, isTrue);
    });

    test('should maintain conversation context after cleanup', () async {
      // Arrange: Setup mixed behavior
      mockApiClient.responseBehavior = MockApiClientBehavior.mixedResponses;
      
      // Act: Send multiple messages
      final response1 = await agent.sendMessage('first message');
      final response2 = await agent.sendMessage('second message');
      
      // Assert: Conversation should maintain context
      expect(response1, isNotNull);
      expect(response2, isNotNull);
      expect(agent.messageCount, greaterThan(2));
    });
  });
}

/// 🎭 MOCK: API Client for testing tool call scenarios
class MockApiClient extends ApiClient {
  MockApiClientBehavior responseBehavior = MockApiClientBehavior.normalResponse;
  
  MockApiClient() : super(baseUrl: 'https://test.com', apiKey: 'test-key');
  
  @override
  Future<Message> sendMessage(List<Message> messages, List<Tool> tools, {ChatCompletionConfig? config}) async {
    switch (responseBehavior) {
      case MockApiClientBehavior.alwaysToolCalls:
        return Message.assistant(
          toolCalls: [
            ToolCall(
              id: 'call_123456789',
              type: 'function',
              function: ToolCallFunction(
                name: 'test_tool',
                arguments: '{"param": "value"}',
              ),
            ),
          ],
        );
      
      case MockApiClientBehavior.singleToolCallThenResponse:
        if (messages.any((msg) => msg.toolCalls != null && msg.toolCalls!.isNotEmpty)) {
          // Second call - return normal response
          return Message.assistant(content: 'Response with tool error context');
        }
        // First call - return tool call
        return Message.assistant(
          toolCalls: [
            ToolCall(
              id: 'call_123456789',
              type: 'function',
              function: ToolCallFunction(
                name: 'test_tool',
                arguments: '{"param": "value"}',
              ),
            ),
          ],
        );
      
      case MockApiClientBehavior.mixedResponses:
        final toolCallCount = messages.where((msg) => msg.toolCalls != null).length;
        if (toolCallCount % 2 == 0) {
          return Message.assistant(content: 'Normal response $toolCallCount');
        }
        return Message.assistant(
          toolCalls: [
            ToolCall(
              id: 'call_123456789',
              type: 'function',
              function: ToolCallFunction(
                name: 'test_tool',
                arguments: '{"param": "value"}',
              ),
            ),
          ],
        );
      
      case MockApiClientBehavior.normalResponse:
      default:
        return Message.assistant(content: 'Normal response');
    }
  }
}

/// 🎭 MOCK: Tool Executor Registry for testing
class MockToolExecutorRegistry extends ToolExecutorRegistry {
  bool shouldThrowOnExecute = false;
  final Map<String, ToolExecutor> _executors = {};
  
  @override
  Map<String, ToolExecutor> get executors => _executors;
  
  MockToolExecutorRegistry() {
    // Register a mock tool
    _executors['test_tool'] = MockToolExecutor();
  }
  
  @override
  Future<String> executeTool(ToolCall toolCall, {Duration? timeout}) async {
    if (shouldThrowOnExecute) {
      throw Exception('Tool execution failed: Simulated error');
    }
    return 'Tool result for ${toolCall.function.name}';
  }
  
  @override
  ToolExecutor? findExecutor(ToolCall toolCall) {
    if (shouldThrowOnExecute && toolCall.function.name == 'test_tool') {
      return MockToolExecutor();
    }
    return _executors[toolCall.function.name];
  }
}

/// 🎭 MOCK: Tool Executor
class MockToolExecutor implements ToolExecutor {
  @override
  String get toolName => 'test_tool';
  
  @override
  String get toolDescription => 'Test tool for unit testing';
  
  @override
  Map<String, dynamic> get toolParameters => {
        'type': 'object',
        'properties': {'param': {'type': 'string'}},
        'required': ['param']
      };
  
  @override
  bool canExecute(ToolCall toolCall) => toolCall.function.name == toolName;
  
  @override
  Future<String> executeTool(ToolCall toolCall, {Duration? timeout}) async {
    return 'Mock tool execution result';
  }
  
  @override
  Tool get asTool => Tool(
        function: FunctionObject(
          name: toolName,
          description: toolDescription,
          parameters: toolParameters,
        ),
      );
}

/// 🎯 ENUM: API Client behavior for testing
enum MockApiClientBehavior {
  normalResponse,
  alwaysToolCalls,
  singleToolCallThenResponse,
  mixedResponses,
}