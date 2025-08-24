/// 🧪 PERMANENT TEST FORTRESS: Tool Call Justification Integration Test
///
/// Tests the complete integration of the tool call loop justification system
/// from the main application down to the API client. This ensures the entire
/// flow works correctly when a tool call loop is detected.
library;

import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:test/test.dart';

/// 🎯 MOCK API CLIENT: Simulates API responses for integration testing
class MockIntegrationApiClient extends ApiClient {
  final bool shouldAcceptJustification;
  int callCount = 0;

  MockIntegrationApiClient({
    required super.baseUrl,
    required super.apiKey,
    required this.shouldAcceptJustification,
  });

  @override
  Future<Message> sendMessage(
    List<Message> messages,
    List<Tool> tools, {
    ChatCompletionConfig? config,
  }) async {
    callCount++;

    // Check if this is a justification request
    final lastMessage = messages.last;
    if (lastMessage.content?.contains('TOOL CALL LOOP JUSTIFICATION REQUEST') ==
        true) {
      if (shouldAcceptJustification) {
        return Message.assistant(
          content:
              '✅ JUSTIFICATION ACCEPTED: This is legitimate complex work requiring multiple tool calls. '
              'The AI is analyzing a large codebase and making progress. Allow continuation.',
        );
      } else {
        return Message.assistant(
          content:
              '❌ JUSTIFICATION DENIED: This appears to be a genuine tool calling loop. '
              'The AI is repeating the same actions without progress. Break into smaller steps.',
        );
      }
    }

    // For non-justification requests, return a normal response
    return Message.assistant(
      content: 'Integration test response to user request (call #$callCount)',
    );
  }
}

/// 🎯 MOCK TOOL REGISTRY: Provides test tools for integration testing
class MockIntegrationToolRegistry implements ToolExecutorRegistry {
  final Map<String, ToolExecutor> _executors = {};

  MockIntegrationToolRegistry() {
    // Add a mock tool executor
    _executors['test_tool'] = MockIntegrationToolExecutor();
  }

  @override
  Map<String, ToolExecutor> get executors => _executors;

  Future<void> initialize() async {}

  Future<void> shutdown() async {}

  @override
  List<Tool> getAllTools() => _executors.values.map((e) => e.asTool).toList();

  @override
  Future<String> executeTool(ToolCall toolCall, {Duration? timeout}) async {
    final executor = findExecutor(toolCall);
    if (executor == null) {
      throw Exception('No executor found for tool: ${toolCall.function.name}');
    }
    return await executor.executeTool(toolCall, timeout: timeout);
  }

  @override
  ToolExecutor? findExecutor(ToolCall toolCall) {
    return _executors[toolCall.function.name];
  }

  @override
  void registerExecutor(ToolExecutor executor) {
    _executors[executor.toolName] = executor;
  }

  @override
  int get executorCount => _executors.length;

  @override
  void clear() {
    _executors.clear();
  }
}

/// 🎯 MOCK TOOL EXECUTOR: Provides test tool execution for integration testing
class MockIntegrationToolExecutor implements ToolExecutor {
  @override
  String get toolName => 'test_tool';

  @override
  String get toolDescription => 'A test tool for integration testing';

  @override
  Map<String, dynamic> get toolParameters => {};

  @override
  bool canExecute(ToolCall toolCall) {
    return toolCall.function.name == toolName;
  }

  @override
  Future<String> executeTool(ToolCall toolCall, {Duration? timeout}) async {
    return 'Integration test tool execution result';
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

/// 🧪 INTEGRATION TEST SUITE: Complete Tool Call Justification System
void main() {
  group('🔧 INTEGRATION: Tool Call Loop Justification System', () {
    late Agent agent;
    late MockIntegrationToolRegistry toolRegistry;
    late MockIntegrationApiClient apiClient;

    setUp(() {
      toolRegistry = MockIntegrationToolRegistry();
      apiClient = MockIntegrationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: true,
      );

      agent = Agent(
        apiClient: apiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are an integration test assistant',
      );
    });

    test(
        '🔧 INTEGRATION: Should handle tool call loop detection and justification flow',
        () async {
      // Simulate the main application flow when a tool call loop is detected
      final originalRequest =
          'Analyze the entire codebase structure and provide comprehensive insights';
      final errorMessage =
          'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.';

      print('🔄 Starting integration test...');
      print('📝 Original request: $originalRequest');
      print('⚠️  Error message: $errorMessage');

      // This simulates what happens in the main application's error handling
      final result = await _handleToolCallLoopError(
        agent,
        originalRequest,
        errorMessage,
      );

      // Verify the result
      expect(result, isNotNull);
      expect(result!.content, contains('Integration test response'));

      // Verify the API was called multiple times (justification + continuation)
      expect(apiClient.callCount, equals(2));

      print('✅ Integration test completed successfully');
      print('📊 API call count: ${apiClient.callCount}');
    });

    test('🔧 INTEGRATION: Should handle justification denial gracefully',
        () async {
      // Configure API to deny justification
      apiClient = MockIntegrationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: false,
      );

      agent = Agent(
        apiClient: apiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are an integration test assistant',
      );

      final originalRequest = 'Analyze the entire codebase structure';
      final errorMessage =
          'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.';

      print('🔄 Starting justification denial test...');

      final result = await _handleToolCallLoopError(
        agent,
        originalRequest,
        errorMessage,
      );

      // Verify the result is null (justification denied)
      expect(result, isNull);

      // Verify only one API call was made (justification request)
      expect(apiClient.callCount, equals(1));

      print('✅ Justification denial test completed successfully');
      print('📊 API call count: ${apiClient.callCount}');
    });

    test(
        '🔧 INTEGRATION: Should maintain conversation state correctly through justification flow',
        () async {
      print('🔄 Starting conversation state test...');

      // Add some initial conversation history
      agent.messages.add(Message.user(content: 'Initial request'));
      agent.messages.add(Message.assistant(content: 'Initial response'));

      final initialMessageCount = agent.messageCount;
      print('📊 Initial message count: $initialMessageCount');

      final originalRequest = 'Analyze the entire codebase structure';
      final errorMessage =
          'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.';

      final result = await _handleToolCallLoopError(
        agent,
        originalRequest,
        errorMessage,
      );

      // Verify the result
      expect(result, isNotNull);

      // After justification and continuation, should have system + user + assistant messages
      final finalMessageCount = agent.messageCount;
      print('📊 Final message count: $finalMessageCount');

      // Should have system + user + assistant messages
      expect(finalMessageCount, equals(3));

      print('✅ Conversation state test completed successfully');
    });

    test(
        '🔧 INTEGRATION: Should use correct API configuration for justification requests',
        () async {
      print('🔄 Starting API configuration test...');

      final originalRequest = 'Analyze the entire codebase structure';
      final errorMessage =
          'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.';

      // Track the configuration used
      ChatCompletionConfig? capturedConfig;

      final trackingApiClient = _ConfigTrackingIntegrationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: true,
        onConfigUsed: (config) {
          // Only capture the first config (justification request)
          capturedConfig ??= config;
        },
      );

      agent = Agent(
        apiClient: trackingApiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are an integration test assistant',
      );

      await _handleToolCallLoopError(
        agent,
        originalRequest,
        errorMessage,
      );

      // Verify the configuration was captured and is correct
      expect(capturedConfig, isNotNull);
      expect(capturedConfig!.temperature, equals(0.3));
      expect(capturedConfig!.maxTokens, equals(500));

      print('✅ API configuration test completed successfully');
      print('🌡️  Temperature: ${capturedConfig!.temperature}');
      print('📏 Max tokens: ${capturedConfig!.maxTokens}');
    });
  });
}

/// 🎯 HELPER: Handle tool call loop error and justification request (integration test version)
///
/// This simulates the exact flow that happens in the main application
/// when a tool call loop error is caught.
Future<Message?> _handleToolCallLoopError(
  Agent agent,
  String originalRequest,
  String errorMessage,
) async {
  try {
    // Create a justification request message (same as in main application)
    final justificationPrompt = '''
⚠️  TOOL CALL LOOP JUSTIFICATION REQUEST

The AI coding assistant has hit the maximum tool call rounds limit (40) while processing your request:

ORIGINAL REQUEST: "$originalRequest"

ERROR: $errorMessage

JUSTIFICATION REQUEST:
Please analyze whether this is actually a tool calling loop or if the AI is legitimately performing a complex analysis that requires many tool calls.

Consider:
1. Is the AI making progress or just repeating the same actions?
2. Is the request inherently complex (e.g., analyzing large codebases, multiple files)?
3. Are the tool calls diverse and purposeful or repetitive?
4. Would breaking the request into smaller parts actually help?

If you determine this is NOT a loop but legitimate complex work:
- Provide a brief explanation of why more tool calls are needed
- Allow the AI to continue with a higher limit or reset the counter
- Give specific guidance on how to proceed efficiently

If you determine this IS a loop:
- Deny the justification request
- Provide specific guidance on how to simplify the approach

RESPOND WITH EITHER:
✅ JUSTIFICATION ACCEPTED: [explanation] + [guidance]
❌ JUSTIFICATION DENIED: [explanation] + [alternative approach]

The AI will then either continue execution or provide the user with alternative guidance.
''';

    print('📤 Sending justification request to API...');

    // Send the justification request to the API (same as in main application)
    final justificationResponse = await agent.apiClient.sendMessage(
      [
        Message.system(content: agent.systemPrompt),
        Message.user(content: justificationPrompt),
      ],
      agent.getFilteredTools(),
      config: agent.apiConfig.copyWith(
        temperature: 0.3, // Lower temperature for more focused reasoning
        maxTokens: 500, // Limit response length for efficiency
      ),
    );

    print(
        '📥 Justification response received: ${justificationResponse.content?.substring(0, 100)}...');

    // Parse the response to determine if justification is accepted (same as in main application)
    final responseContent = justificationResponse.content?.toLowerCase() ?? '';

    if (responseContent.contains('justification accepted') ||
        responseContent.contains('✅') ||
        responseContent.contains('accepted')) {
      print('📥 Justification accepted by API');

      // Reset the agent's message state to continue with the original request
      // Clear any incomplete tool call state
      agent.clearConversation();

      // Send the original request again, but this time with a note about the justification
      final continuationMessage = '''
CONTINUING EXECUTION AFTER JUSTIFICATION APPROVAL

Your request has been reviewed and approved for continuation. The AI will now proceed with your original request:

"$originalRequest"

The API has determined that this is legitimate complex work requiring multiple tool calls, not a loop.
''';

      print('🔄 Continuing execution with original request...');
      return await agent.sendMessage(continuationMessage);
    } else if (responseContent.contains('justification denied') ||
        responseContent.contains('❌') ||
        responseContent.contains('denied')) {
      print('📥 Justification denied by API');
      return null;
    } else {
      // Ambiguous response - treat as denied for safety
      print('📥 Ambiguous API response - treating as denied for safety');
      return null;
    }
  } catch (e) {
    print('❌ Justification request failed: $e');
    return null;
  }
}

/// 🎯 HELPER: API Client that tracks configuration usage for integration testing
class _ConfigTrackingIntegrationApiClient extends MockIntegrationApiClient {
  final void Function(ChatCompletionConfig) onConfigUsed;

  _ConfigTrackingIntegrationApiClient({
    required super.baseUrl,
    required super.apiKey,
    required super.shouldAcceptJustification,
    required this.onConfigUsed,
  });

  @override
  Future<Message> sendMessage(
    List<Message> messages,
    List<Tool> tools, {
    ChatCompletionConfig? config,
  }) async {
    if (config != null) {
      onConfigUsed(config);
    }
    return super.sendMessage(messages, tools, config: config);
  }
}
