import "dart:convert";
import "dart:io";

import 'package:dart_ai_coding_assistant/cache_manager.dart';
import 'package:dart_ai_coding_assistant/mcp_hot_reload.dart';
import "package:dart_openai_client/dart_openai_client.dart";

/// Multi-line terminal input handler with proper line wrapping and editing support
String _getUserInput() {
  try {
    stdout.write("\nEnter your coding request (press Ctrl+Enter to finish):\n");
    stdout.flush();

    final lines = <String>[];
    String currentInput = '';

    while (true) {
      // Read a line from stdin
      final line = stdin.readLineSync();
      if (line == null) {
        // EOF reached
        break;
      }

      if (line.isEmpty) {
        // Empty line after content - treat as completion
        if (lines.isNotEmpty || currentInput.isNotEmpty) {
          break;
        }
      } else {
        // Add line to input
        if (currentInput.isNotEmpty) {
          currentInput += '\n';
        }
        currentInput += line;
        lines.add(line);
      }
    }

    return currentInput.trim();
  } catch (e) {
    // If there's an issue with stdin, provide a clear message
    print("\n⚠️  Input error. Please try again.");
    return '';
  }
}

/// AI CODING ASSISTANT: Professional Code Analysis & Development
///
/// Provides:
/// 1. Codebase analysis and architectural insights
/// 2. Filesystem access for project structure analysis
/// 3. Code quality assessment and technical debt analysis
/// 4. Refactoring recommendations
/// 5. Integration with development tools
/// 6. Interactive code review workflow
///
/// Security: Read-only operations by default, validation of file operations
Future<void> main() async {
  print("AI CODING ASSISTANT: Code Analysis & Development");
  print("=" * 50);
  print("Professional code analysis and refactoring assistance");
  print("=" * 50);

  final tipsFile = File("bin/coding_assistant_tips.txt");
  String tips = "";
  if (tipsFile.existsSync()) {
    tips = tipsFile.readAsStringSync();
  }

  // Environment validation: Ensure API key is available
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception("❌ CRITICAL FAILURE: DEEPSEEK_API_KEY is not set");
  }

  // Client initialization: Setup API client
  final client = ApiClient(
    baseUrl: "https://api.deepseek.com/v1",
    apiKey: apiKey,
  );

  // MCP configuration: Load and initialize MCP servers
  final mcpConfig = File("config/mcp_servers.json");
  if (!mcpConfig.existsSync()) {
    throw Exception(
        "❌ CRITICAL FAILURE: MCP configuration not found at config/mcp_servers.json");
  }

  final toolRegistry = McpToolExecutorRegistry(mcpConfig: mcpConfig);
  await toolRegistry.initialize();
  print("✅ MCP servers initialized successfully");

  // Initialize cache manager
  print("🗄️  Cache manager initialized");
  print("📊 Cache stats: ${cacheManager.getCacheStats()}");

  // Hot reload manager: Enable MCP server hot reloading
  final hotReloadManager = McpHotReloadManager();
  await hotReloadManager.initialize(
    configPath: "config/mcp_servers.json",
    toolRegistry: toolRegistry,
    watchForChanges: true,
  );

  // System prompt construction: Build coding context
  final systemPrompt = _buildSystemPrompt(tips);

  // Agent initialization: Create coding assistant agent
  final agent = Agent(
    apiClient: client,
    toolRegistry: toolRegistry,
    systemPrompt: systemPrompt,
  )..temperature = 0.8; // Higher temperature for creative technical insights

  print("✅ Coding Assistant initialized and ready");
  print("=" * 50);

  // Project analysis: Perform initial codebase assessment with caching
  await _performInitialAnalysis(toolRegistry);

  try {
    // Interactive workflow: Main coding assistance loop
    await _runInteractiveWorkflow(agent, hotReloadManager);
  } finally {
    // Cleanup: Ensure proper shutdown
    print("\nShutting down systems...");
    await hotReloadManager.dispose();
    await toolRegistry.shutdown();
    await client.close();
    print("✅ Clean shutdown completed");
  }
}

/// Project analysis: Perform initial codebase assessment
Future<void> _performInitialAnalysis(
    McpToolExecutorRegistry toolRegistry) async {
  print("🔍 Performing initial project analysis...");

  try {
    // Get project structure with caching
    try {
      await cacheManager.getDirectoryTreeWithCache(".");
      print("📁 Project structure cached and analyzed");
    } catch (e) {
      print(
          "⚠️  Cached structure analysis failed, falling back to direct tool: $e");
      final structureCall = ToolCall(
        id: 'analyze_structure_${DateTime.now().millisecondsSinceEpoch}',
        type: 'function',
        function: ToolCallFunction(
          name: 'directory_tree',
          arguments: jsonEncode({"path": "."}),
        ),
      );
      await toolRegistry.executeTool(structureCall);
    }

    // Get pubspec.yaml for dependencies with caching
    try {
      await cacheManager.readFileWithCache("pubspec.yaml");
      print("📦 Dependencies cached and analyzed");
    } catch (e) {
      print(
          "⚠️  Cached pubspec analysis failed, falling back to direct tool: $e");
      final pubspecCall = ToolCall(
        id: 'read_pubspec_${DateTime.now().millisecondsSinceEpoch}',
        type: 'function',
        function: ToolCallFunction(
          name: 'read_text_file',
          arguments: jsonEncode({"path": "pubspec.yaml"}),
        ),
      );
      await toolRegistry.executeTool(pubspecCall);
    }

    print("✅ Project structure analyzed");
    print("✅ Dependencies identified");
  } catch (e) {
    print("⚠️  Initial analysis limited: $e");
    print("📝 Proceeding with standard coding assistance...");
  }
}

/// Interactive workflow: Main coding assistance loop
Future<void> _runInteractiveWorkflow(
    Agent agent, McpHotReloadManager hotReloadManager) async {
  print("INTERACTIVE CODE ANALYSIS");
  print(
      "Enter your coding request, file path for review, or architectural question.");
  print("Available commands:");
  print("  - 'analyze <file/dir>' - Code analysis");
  print("  - 'review <file>' - Code review");
  print("  - 'arch <topic>' - Architectural guidance");
  print("  - 'refactor <file>' - Refactoring recommendations");
  print("  - 'reload' - Hot reload MCP servers");
  print("  - 'mcp status' - Show MCP server status");
  print("  - 'cache stats' - Show cache statistics");
  print("  - 'cache clear' - Clear all caches");
  print("  - 'exit', 'quit', or 'done' - End session");
  print(
      "\n💡 TIP: Multi-line input - type your request and press Enter twice to finish.");
  print("=" * 50);

  while (true) {
    // User input: Get coding request with improved terminal handling
    final userInput = _getUserInput();

    if (userInput.isEmpty) {
      print("❌ No input provided. Please enter a coding request.");
      continue;
    }

    // Check for hot reload commands first
    final commandHandled = await hotReloadManager.processCommand(userInput);
    if (commandHandled) {
      continue;
    }

    // Check for cache management commands
    if (userInput.toLowerCase() == 'cache stats') {
      final stats = cacheManager.getCacheStats();
      print("📊 CACHE STATISTICS:");
      print("   File Cache: ${stats['fileCacheSize']} entries");
      print("   Directory Cache: ${stats['directoryCacheSize']} entries");
      print(
          "   Project Analysis Cache: ${stats['projectAnalysisCacheSize']} entries");
      print("   Hits: ${stats['hits']}, Misses: ${stats['misses']}");
      print("   Hit Rate: ${(stats['hitRate'] * 100).toStringAsFixed(1)}%");
      print("   Invalidations: ${stats['invalidations']}");
      continue;
    }

    if (userInput.toLowerCase() == 'cache clear') {
      cacheManager.clearCache();
      print("✅ All caches cleared");
      continue;
    }

    // Exit conditions: Check for session termination
    if (['exit', 'quit', 'done'].contains(userInput.toLowerCase())) {
      // Show final cache statistics
      final stats = cacheManager.getCacheStats();
      print("📊 FINAL CACHE STATISTICS:");
      print("   Total Hits: ${stats['hits']}, Misses: ${stats['misses']}");
      print(
          "   Overall Hit Rate: ${(stats['hitRate'] * 100).toStringAsFixed(1)}%");
      print(
          "   Estimated API Cost Reduction: ~${(stats['hitRate'] * 30).toStringAsFixed(1)}%");

      print("Session terminated.");
      break;
    }

    print("\nProcessing request: \"$userInput\"");
    print("-" * 40);

    try {
      // Agent processing: Send to coding assistant
      final result = await agent.sendMessage(userInput);

      // Results display: Show coding insights
      print("ANALYSIS COMPLETE:");
      print(result.content);

      // Session continuation: Prepare for next request
      print("-" * 40);
      print("✅ Analysis completed. Ready for next request.");
    } catch (e) {
      // Error handling: Handle coding assistance failures
      print("❌ ANALYSIS FAILED: $e");
      print("Try a different approach or file path.");
    }
  }
}

/// System prompt builder: Create coding context
String _buildSystemPrompt(String tips) {
  return """
AI CODING ASSISTANT: Code Analysis & Development

You are an AI coding assistant that provides professional code analysis and development guidance.

Your main goal right now is to improve your own codebase. Your codebase consists of 2 projects:
The current project located in the current directory.
The second project located in the ../dart_openai_client directory.
You can use the tools to analyze and improve both projects.

We own the dart_openai_client project. You can use the tools to analyze and improve it.

Log what you do locally and maintain a local todo list so if you are interrupted you can pick up where you left off.

AVAILABLE TOOLS:
- Filesystem access for project structure analysis
- Code analysis tools for Dart code examination
- Project understanding via pubspec.yaml and dependencies
- Integration with development tools
- File-specific code reviews

CAPABILITIES:
- Codebase analysis and architectural assessment
- Technical insights based on software engineering principles
- Actionable recommendations for code improvement
- Code quality and maintainability evaluation
- Professional technical documentation

PROJECT CONTEXT:
You are assisting with Dart development projects. The environment includes:
- Multiple MCP servers for development operations
- Integration with AI models for code generation and analysis
- Modern Dart architecture patterns and best practices
- Professional software engineering principles

RESPONSE STRATEGY:
1. Analyze project structure and relevant files using available tools
2. Provide specific, actionable technical recommendations
3. Create practical development roadmap with next steps
4. Deliver clear vision of optimized code architecture
5. Summarize with practical technical insights

ACTION PROTOCOL:
When user provides file path or coding request:
1. Use filesystem tools to read and analyze relevant code
2. Examine project context and architecture
3. Provide specific recommendations with code examples
4. Justify recommendations with technical reasoning

TESTING PROTOCOL:
🧪 PERMANENT TEST FORTRESS PROTOCOL [MANDATORY]
- EVERY investigation, bug fix, or feature MUST create permanent unit tests in test/ folder
- NO temporary test scripts that get deleted after use
- Tests serve as living documentation and regression protection
- Test naming convention: test_<component>_<functionality>.dart
- Include comprehensive test coverage for edge cases and error conditions
- Use descriptive test names that explain WHAT is being verified
- Group related tests logically within test files
- Maintain test quality equal to production code standards

BANNED PRACTICES:
- Creating temporary test files for investigation only
- Deleting tests after verification is complete  
- One-off diagnostic scripts that don't persist
- Testing in main() functions or standalone scripts

REQUIRED TEST STRUCTURE:
test/
├── unit/           # Unit tests for individual components
├── integration/    # Integration tests for component interaction
├── mcp/           # MCP server functionality tests
└── fixtures/      # Test data and mock objects


File naming conventions:
- test/integration/config_modification_test.dart
- test/unit/config_modification_test.dart
- test/mcp/config_modification_test.dart
- test/fixtures/config_modification_test.dart


CONTINUOUS IMPROVEMENT PROTOCOL:
- When encountering tooling errors, consider what could be improved in the tooling. Log this to docs/TOOLING_IMPROVEMENTS.md
- When encountering a bug, consider what could be improved in the code. Log this to docs/BUG_FIXES.md
- When encountering a feature request, consider what could be improved in the code. Log this to docs/FEATURE_REQUESTS.md
- When encountering a performance issue, consider what could be improved in the code. Log this to docs/PERFORMANCE_ISSUES.md
- When encountering a security issue, consider what could be improved in the code. Log this to docs/SECURITY_ISSUES.md
- When encountering a usability issue, consider what could be improved in the code. Log this to docs/USABILITY_ISSUES.md
- When encountering a documentation issue, consider what could be improved in the code. Log this to docs/DOCUMENTATION_ISSUES.md
- When encountering a test issue, consider what could be improved in the code. Log this to docs/TEST_ISSUES.md
- If you run out of tool calls and need to continue, first consider what tools could have resolved your work in a minimum of calls and log them to docs/TOOL_CALL_JUSTIFICATION_SOLUTION.md

Every code change must include corresponding test updates or new test creation.
Tests are permanent assets that protect against regressions and document expected behavior.


Be direct, professional, and focused on practical solutions. Avoid unnecessary fluff or self-aggrandizement.

Tips:
$tips
""";
}
