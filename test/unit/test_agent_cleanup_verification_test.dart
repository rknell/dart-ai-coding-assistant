import 'package:test/test.dart';
import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:dart_openai_client/src/agent.dart';
import 'package:dart_openai_client/src/api_client.dart';
import 'package:dart_openai_client/src/tool_executor.dart';
import 'package:dart_openai_client/src/message.dart';
import 'package:dart_openai_client/src/tool.dart';

/// 🧪 TEST: Agent Cleanup Verification
/// 
/// Tests that verify the cleanup mechanism actually works by examining
/// the conversation history after tool call round limits are exceeded.
void main() {
  group('Agent Cleanup Verification', () {
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

    test('should add error responses for incomplete tool calls', () async {
      // Arrange: Setup API client to always return tool calls
      mockApiClient.responseBehavior = MockApiClientBehavior.alwaysToolCalls;
      
      try {
        // Act: This should throw due to max tool call rounds
        await agent.sendMessage('test message');
        fail('Expected exception due to max tool call rounds');
      } catch (e) {
        // Assert: Verify cleanup was performed
        expect(e.toString(), contains('Maximum tool call rounds exceeded'));
        
        // Check that error responses were added to conversation
        final errorMessages = agent.conversationHistory
            .where((msg) => msg.content?.contains('ERROR: Tool execution terminated') ?? false);
        
        final systemInterventionMessages = agent.conversationHistory
            .where((msg) => msg.content?.contains('SYSTEM INTERVENTION') ?? false);
        
        expect(errorMessages.isNotEmpty, isTrue);
        expect(systemInterventionMessages.isNotEmpty, isTrue);
        
        // Verify the conversation is in a clean state
        expect(agent.messageCount, greaterThan(2)); // Should have some messages
        expect(agent.messageCount, lessThan(100)); // But not excessively many
      }
    });

    test('should maintain tool call IDs in error responses', () async {
      // Arrange: Setup API client to always return tool calls
      mockApiClient.responseBehavior = MockApiClientBehavior.alwaysToolCalls;
      
      try {
        // Act: This should throw due to max tool call rounds
        await agent.sendMessage('test message');
        fail('Expected exception due to max tool call rounds');
      } catch (e) {
        // Assert: Verify tool call IDs are preserved in error responses
        final toolResultMessages = agent.conversationHistory
            .where((msg) => msg.role == 'tool' && msg.toolCallId != null);
        
        expect(toolResultMessages.isNotEmpty, isTrue);
        
        // All tool result messages should have non-empty content
        for (final msg in toolResultMessages) {
          expect(msg.content, isNotNull);
          expect(msg.content!.isNotEmpty, isTrue);
          expect(msg.toolCallId, isNotNull);
          expect(msg.toolCallId!.isNotEmpty, isTrue);
        }
      }
    });

    test('should not pollute context with infinite tool call loops', () async {
      // Arrange: Setup API client to always return tool calls
      mockApiClient.responseBehavior = MockApiClientBehavior.alwaysToolCalls;
      
      // Capture initial message count
      final initialCount = agent.messageCount;
      
      try {
        // Act: This should throw due to max tool call rounds
        await agent.sendMessage('test message');
        fail('Expected exception due to max tool call rounds');
      } catch (e) {
        // Assert: Verify the conversation didn't grow excessively
        final finalCount = agent.messageCount;
        
        // Should have added some messages for cleanup, but not excessively many
        expect(finalCount, greaterThan(initialCount));
        expect(finalCount - initialCount, lessThan(100)); // Reasonable cleanup overhead
        
        // Verify no dangling tool calls without responses
        final assistantMessagesWithToolCalls = agent.conversationHistory
            .where((msg) => msg.role == 'assistant' && msg.toolCalls != null && msg.toolCalls!.isNotEmpty);
        
        final toolResults = agent.conversationHistory
            .where((msg) => msg.role == 'tool');
        
        // Every tool call should have a corresponding result
        expect(assistantMessagesWithToolCalls.length, lessThanOrEqualTo(toolResults.length));
      }
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
    return 'Tool result for ' + toolCall.function.name;
  }
  
  @override
  ToolExecutor? findExecutor(ToolCall toolCall) {
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
}