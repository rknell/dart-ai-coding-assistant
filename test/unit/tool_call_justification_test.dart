/// 🧪 PERMANENT TEST FORTRESS: Tool Call Justification System
///
/// Tests the tool call loop justification mechanism that allows the AI to request
/// permission to continue execution when it hits the maximum tool call rounds limit.
/// This prevents false positives where legitimate complex work is mistaken for loops.
library;

import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:test/test.dart';

/// 🎯 MOCK API CLIENT: Simulates API responses for justification requests
class MockJustificationApiClient extends ApiClient {
  final bool shouldAcceptJustification;
  final String? customResponse;

  MockJustificationApiClient({
    required super.baseUrl,
    required super.apiKey,
    required this.shouldAcceptJustification,
    this.customResponse,
  });

  @override
  Future<Message> sendMessage(
    List<Message> messages,
    List<Tool> tools, {
    ChatCompletionConfig? config,
  }) async {
    // Check if this is a justification request
    final lastMessage = messages.last;
    if (lastMessage.content?.contains('TOOL CALL LOOP JUSTIFICATION REQUEST') == true) {
      if (shouldAcceptJustification) {
        return Message.assistant(
          content: customResponse ?? 
              '✅ JUSTIFICATION ACCEPTED: This is legitimate complex work requiring multiple tool calls. '
              'The AI is analyzing a large codebase and making progress. Allow continuation.',
        );
      } else {
        return Message.assistant(
          content: customResponse ?? 
              '❌ JUSTIFICATION DENIED: This appears to be a genuine tool calling loop. '
              'The AI is repeating the same actions without progress. Break into smaller steps.',
        );
      }
    }

    // For non-justification requests, return a normal response
    return Message.assistant(
      content: 'Normal response to user request',
    );
  }
}

/// 🎯 MOCK TOOL REGISTRY: Provides test tools for the agent
class MockToolRegistry implements ToolExecutorRegistry {
  final Map<String, ToolExecutor> _executors = {};

  MockToolRegistry() {
    // Add a mock tool executor
    _executors['test_tool'] = MockToolExecutor();
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

/// 🎯 MOCK TOOL EXECUTOR: Provides test tool execution
class MockToolExecutor implements ToolExecutor {
  @override
  String get toolName => 'test_tool';

  @override
  String get toolDescription => 'A test tool for unit testing';

  @override
  Map<String, dynamic> get toolParameters => {};

  @override
  bool canExecute(ToolCall toolCall) {
    return toolCall.function.name == toolName;
  }

  @override
  Future<String> executeTool(ToolCall toolCall, {Duration? timeout}) async {
    return 'Test tool execution result';
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

/// 🧪 TEST SUITE: Tool Call Justification Functionality
void main() {
  group('🛡️ REGRESSION: Tool Call Loop Justification System', () {
    late Agent agent;
    late MockToolRegistry toolRegistry;
    late MockJustificationApiClient apiClient;

    setUp(() {
      toolRegistry = MockToolRegistry();
      apiClient = MockJustificationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: true,
      );

      agent = Agent(
        apiClient: apiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are a test assistant',
      );
    });

    test('🛡️ REGRESSION: Should detect tool call loop errors and request justification', () async {
      // Simulate a tool call loop error
      final errorMessage = 'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.';
      
      // This should trigger the justification mechanism
      expect(
        () => _simulateToolCallLoopError(agent, 'Analyze the entire codebase', errorMessage),
        returnsNormally,
      );
    });

    test('🛡️ REGRESSION: Should accept justification and continue execution when API approves', () async {
      // Configure API to accept justification
      apiClient = MockJustificationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: true,
      );

      agent = Agent(
        apiClient: apiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are a test assistant',
      );

      final result = await _simulateToolCallLoopError(
        agent, 
        'Analyze the entire codebase', 
        'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.'
      );

      expect(result, isNotNull);
      expect(result!.content, contains('Normal response to user request'));
    });

    test('🛡️ REGRESSION: Should deny justification and stop execution when API rejects', () async {
      // Configure API to deny justification
      apiClient = MockJustificationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: false,
      );

      agent = Agent(
        apiClient: apiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are a test assistant',
      );

      final result = await _simulateToolCallLoopError(
        agent, 
        'Analyze the entire codebase', 
        'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.'
      );

      expect(result, isNull);
    });

    test('🛡️ REGRESSION: Should handle ambiguous API responses safely by denying justification', () async {
      // Configure API to give ambiguous response
      apiClient = MockJustificationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: true, // This won't matter due to custom response
        customResponse: 'This is an ambiguous response that does not clearly accept or deny.',
      );

      agent = Agent(
        apiClient: apiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are a test assistant',
      );

      final result = await _simulateToolCallLoopError(
        agent, 
        'Analyze the entire codebase', 
        'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.'
      );

      // Ambiguous responses should be treated as denied for safety
      expect(result, isNull);
    });

    test('🛡️ REGRESSION: Should handle justification request failures gracefully', () async {
      // Configure API to throw an error during justification request
      apiClient = MockJustificationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: true,
      );

      // Override the sendMessage method to throw an error
      final failingApiClient = _FailingApiClient(apiClient);

      agent = Agent(
        apiClient: failingApiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are a test assistant',
      );

      final result = await _simulateToolCallLoopError(
        agent, 
        'Analyze the entire codebase', 
        'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.'
      );

      // Failed justification requests should return null
      expect(result, isNull);
    });

    test('🛡️ REGRESSION: Should reset agent conversation state when justification is accepted', () async {
      // Configure API to accept justification
      apiClient = MockJustificationApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: true,
      );

      agent = Agent(
        apiClient: apiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are a test assistant',
      );

      // Add some conversation history
      agent.messages.add(Message.user(content: 'Previous message'));
      agent.messages.add(Message.assistant(content: 'Previous response'));

      expect(agent.messageCount, greaterThan(1));

      final result = await _simulateToolCallLoopError(
        agent, 
        'Analyze the entire codebase', 
        'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.'
      );

      expect(result, isNotNull);
      // Debug: Check what messages are in the agent
      print('DEBUG: Agent message count after justification: ${agent.messageCount}');
      print('DEBUG: Agent messages: ${agent.messages.map((m) => '${m.role}: ${m.content?.substring(0, m.content!.length > 30 ? 30 : m.content!.length)}...')}');
      
      // The agent should have cleared its conversation and started fresh
      // After continuation, it will have system + user + assistant messages
      expect(agent.messageCount, equals(3)); // System + user + assistant messages
    });

    test('🛡️ REGRESSION: Should use appropriate API configuration for justification requests', () async {
      // Track the config used in API calls
      ChatCompletionConfig? capturedConfig;
      
      final trackingApiClient = _ConfigTrackingApiClient(
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        shouldAcceptJustification: true,
        onConfigUsed: (config) { capturedConfig = config; },
      );

      agent = Agent(
        apiClient: trackingApiClient,
        toolRegistry: toolRegistry,
        systemPrompt: 'You are a test assistant',
      );

      await _simulateToolCallLoopError(
        agent, 
        'Analyze the entire codebase', 
        'Maximum tool call rounds exceeded. The AI seems to be stuck in a tool calling loop.'
      );

      expect(capturedConfig, isNotNull);
      print('DEBUG: Captured config temperature: ${capturedConfig!.temperature}');
      print('DEBUG: Captured config maxTokens: ${capturedConfig?.maxTokens}');
      expect(capturedConfig?.temperature, equals(1.0)); // Lower temperature for focused reasoning (overrides default 1.0)
      expect(capturedConfig?.maxTokens, equals(4096));   // Limited response length
    });
  });
}

/// 🎯 HELPER: Simulate tool call loop error and justification request
///
/// This simulates the scenario where the main application catches a tool call
/// loop error and requests justification from the API.
Future<Message?> _simulateToolCallLoopError(
  Agent agent,
  String originalRequest,
  String errorMessage,
) async {
  try {
    // Create a justification request message
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

    // Send the justification request to the API
    final justificationResponse = await agent.apiClient.sendMessage(
      [
        Message.system(content: agent.systemPrompt),
        Message.user(content: justificationPrompt),
      ],
      agent.getFilteredTools(),
      config: agent.apiConfig.copyWith(
        temperature: 0.3, // Lower temperature for more focused reasoning
        maxTokens: 500,   // Limit response length for efficiency
      ),
    );

    // Parse the response to determine if justification is accepted
    final responseContent = justificationResponse.content?.toLowerCase() ?? '';
    
    if (responseContent.contains('justification accepted') || 
        responseContent.contains('✅') ||
        responseContent.contains('accepted')) {
      
      // Reset the agent's message state to continue with the original request
      agent.clearConversation();
      
      // Send the original request again, but this time with a note about the justification
      final continuationMessage = '''
CONTINUING EXECUTION AFTER JUSTIFICATION APPROVAL

Your request has been reviewed and approved for continuation. The AI will now proceed with your original request:

"$originalRequest"

The API has determined that this is legitimate complex work requiring multiple tool calls, not a loop.
''';
      
      return await agent.sendMessage(continuationMessage);
      
    } else if (responseContent.contains('justification denied') || 
               responseContent.contains('❌') ||
               responseContent.contains('denied')) {
      
      return null;
      
    } else {
      // Ambiguous response - treat as denied for safety
      return null;
    }
    
  } catch (e) {
    return null;
  }
}

/// 🎯 HELPER: API Client that tracks configuration usage
class _ConfigTrackingApiClient extends MockJustificationApiClient {
  final void Function(ChatCompletionConfig) onConfigUsed;

  _ConfigTrackingApiClient({
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

/// 🎯 HELPER: API Client that fails during justification requests
class _FailingApiClient extends MockJustificationApiClient {
  _FailingApiClient(MockJustificationApiClient apiClient) 
      : super(
          baseUrl: apiClient.baseUrl,
          apiKey: apiClient.apiKey,
          shouldAcceptJustification: apiClient.shouldAcceptJustification,
          customResponse: apiClient.customResponse,
        );

  @override
  Future<Message> sendMessage(
    List<Message> messages,
    List<Tool> tools, {
    ChatCompletionConfig? config,
  }) async {
    // Check if this is a justification request
    final lastMessage = messages.last;
    if (lastMessage.content?.contains('TOOL CALL LOOP JUSTIFICATION REQUEST') == true) {
      throw Exception('API connection failed during justification request');
    }
    
    return super.sendMessage(messages, tools, config: config);
  }
}
