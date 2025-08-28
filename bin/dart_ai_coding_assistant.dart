import "dart:convert";
import "dart:io";

import 'package:dart_ai_coding_assistant/cache_manager.dart';
import 'package:dart_ai_coding_assistant/logging_config.dart';
import 'package:dart_ai_coding_assistant/mcp_hot_reload.dart';
import "package:dart_openai_client/dart_openai_client.dart";

/// 🎯 PROJECT ROOT DETECTION: Find the dart-ai-coding-assistant project root
///
/// This function determines the project root directory by looking for key project files
/// and handles execution from any working directory.
String _findProjectRoot() {
  // Start from current working directory
  String currentDir = Directory.current.path;

  // Walk up the directory tree looking for project root indicators
  while (currentDir != '/' && currentDir != '') {
    final pubspecFile = File('$currentDir/pubspec.yaml');
    final mcpConfigFile = File('$currentDir/config/mcp_servers.json');
    final binDir = Directory('$currentDir/bin');
    final mcpDir = Directory('$currentDir/mcp');

    // Check if this looks like our project root
    // Must have ALL required directories and files
    if (pubspecFile.existsSync() &&
        mcpConfigFile.existsSync() &&
        binDir.existsSync() &&
        mcpDir.existsSync()) {
      // Additional validation: check if this is actually our project
      final mainProgram = File('$currentDir/bin/dart_ai_coding_assistant.dart');
      if (mainProgram.existsSync()) {
        logInfo("Project root found at: $currentDir", component: "MAIN");
        return currentDir;
      }
    }

    // Move up one directory
    final parentDir = Directory(currentDir).parent.path;
    if (parentDir == currentDir) break; // Prevent infinite loop
    currentDir = parentDir;
  }

  // If we can't find the project root, try to find it by looking for the specific project name
  // This handles cases where we're in a parent directory with multiple dart projects
  final projectName = 'dart-ai-coding-assistant';

  // Look for the project in parent directories, not just the current directory
  String searchDir = Directory.current.path;
  while (searchDir != '/' && searchDir != '') {
    final possibleProjectRoot = '$searchDir/$projectName';
    final possibleProjectDir = Directory(possibleProjectRoot);

    if (possibleProjectDir.existsSync()) {
      final pubspecFile = File('$possibleProjectRoot/pubspec.yaml');
      final mcpConfigFile =
          File('$possibleProjectRoot/config/mcp_servers.json');
      final binDir = Directory('$possibleProjectRoot/bin');
      final mcpDir = Directory('$possibleProjectRoot/mcp');
      final mainProgram =
          File('$possibleProjectRoot/bin/dart_ai_coding_assistant.dart');

      if (pubspecFile.existsSync() &&
          mcpConfigFile.existsSync() &&
          binDir.existsSync() &&
          mcpDir.existsSync() &&
          mainProgram.existsSync()) {
        logInfo("Project root found at: $possibleProjectRoot",
            component: "MAIN");
        return possibleProjectRoot;
      }
    }

    // Move up one directory
    final parentDir = Directory(searchDir).parent.path;
    if (parentDir == searchDir) break; // Prevent infinite loop
    searchDir = parentDir;
  }

  // If we still can't find the project root, this is a critical error
  // Don't fall back to current directory as it might be wrong
  throw Exception(
      "❌ CRITICAL FAILURE: dart-ai-coding-assistant project root not found. "
      "Please run this program from within the dart-ai-coding-assistant project "
      "or from a parent directory that contains it. "
      "Current directory: ${Directory.current.path}");
}

/// 🔧 MCP PATH RESOLUTION: Convert relative paths to absolute paths
///
/// Ensures MCP server paths are resolved relative to the project root,
/// not the current working directory.
String _resolveMcpPath(String projectRoot, String relativePath) {
  if (relativePath.startsWith('/')) {
    return relativePath; // Already absolute
  }

  final resolvedPath = '$projectRoot/$relativePath';
  logDebug("Resolved MCP path: $relativePath -> $resolvedPath",
      component: "MAIN");
  return resolvedPath;
}

/// 🔧 MCP SERVER PATH RESOLUTION: Resolve all MCP server paths and working directories
///
/// Creates a new MCP configuration file with all paths resolved to absolute paths
/// and working directories set to the project root.
Future<File> _resolveMcpServerPaths(
    String projectRoot, File originalConfig) async {
  try {
    // Read the original configuration
    final configContent = await originalConfig.readAsString();

    // Instead of trying to modify maps, create a new JSON string with resolved paths
    String resolvedContent = configContent;

    // Replace working directory references
    resolvedContent = resolvedContent.replaceAll(
        '"workingDirectory": "."', '"workingDirectory": "$projectRoot"');

    // Replace MCP server paths
    resolvedContent = resolvedContent.replaceAll(
        'mcp/', _resolveMcpPath(projectRoot, "mcp/"));

    // Add environment variable for working directory
    resolvedContent = resolvedContent.replaceAll(
        '"env": {}', '"env": {"MCP_WORKING_DIRECTORY": "$projectRoot"}');

    // Create a temporary resolved configuration file
    final resolvedConfigFile = File('${originalConfig.path}.resolved');
    await resolvedConfigFile.writeAsString(resolvedContent);

    logInfo("MCP server paths resolved for project root: $projectRoot",
        component: "MAIN");
    return resolvedConfigFile;
  } catch (e) {
    logWarn("Failed to resolve MCP server paths, using original config: $e",
        component: "MAIN");
    return originalConfig;
  }
}

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
  // Initialize logging system first
  logging.initialize();

  print("AI CODING ASSISTANT: Code Analysis & Development");
  print("=" * 50);
  print("Professional code analysis and refactoring assistance");
  print("=" * 50);
  logInfo("Starting AI Coding Assistant", component: "MAIN");
  logInfo("Log level: ${logging.levelName}", component: "MAIN");

  // 🎯 PROJECT ROOT DETECTION: Find the project root regardless of execution directory
  final projectRoot = _findProjectRoot();
  logInfo("Working from project root: $projectRoot", component: "MAIN");
  logInfo("Current working directory: ${Directory.current.path}",
      component: "MAIN");

  final tipsFile =
      File(_resolveMcpPath(projectRoot, "bin/coding_assistant_tips.txt"));
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

  // MCP configuration: Load and initialize MCP servers with resolved paths
  final mcpConfigPath = _resolveMcpPath(projectRoot, "config/mcp_servers.json");
  final mcpConfig = File(mcpConfigPath);
  if (!mcpConfig.existsSync()) {
    throw Exception(
        "❌ CRITICAL FAILURE: MCP configuration not found at $mcpConfigPath");
  }

  // 🔧 MCP PATH RESOLUTION: Update MCP server configuration with absolute paths
  final resolvedMcpConfig =
      await _resolveMcpServerPaths(projectRoot, mcpConfig);

  final toolRegistry = McpToolExecutorRegistry(mcpConfig: resolvedMcpConfig);
  await toolRegistry.initialize();
  logInfo("MCP servers initialized successfully", component: "MAIN");

  // Initialize cache manager
  logInfo("Cache manager initialized", component: "MAIN");
  if (logging.isDebugMode) {
    final stats = cacheManager.getCacheStats();
    logDebug("Cache stats: $stats", component: "CACHE");
  }

  // Hot reload manager: Enable MCP server hot reloading with resolved paths
  final hotReloadManager = McpHotReloadManager();
  await hotReloadManager.initialize(
    configPath: mcpConfigPath,
    toolRegistry: toolRegistry,
    watchForChanges: true,
  );
  logInfo("Hot reload manager initialized", component: "MAIN");

  // System prompt construction: Build coding context
  final systemPrompt = _buildSystemPrompt(tips);

  // Agent initialization: Create coding assistant agent
  final agent = Agent(
    apiClient: client,
    toolRegistry: toolRegistry,
    systemPrompt: systemPrompt,
  )..temperature = 0.8; // Higher temperature for creative technical insights

  logInfo("Coding Assistant initialized and ready", component: "MAIN");
  print("=" * 50);

  // Project analysis: Perform initial codebase assessment with caching
  await _performInitialAnalysis(toolRegistry);

  try {
    // Interactive workflow: Main coding assistance loop
    await _runInteractiveWorkflow(agent, hotReloadManager);
  } finally {
    // Cleanup: Ensure proper shutdown
    logInfo("Shutting down systems...", component: "MAIN");
    await hotReloadManager.dispose();
    await toolRegistry.shutdown();
    await client.close();
    logInfo("Clean shutdown completed", component: "MAIN");
  }
}

/// Project analysis: Perform initial codebase assessment
Future<void> _performInitialAnalysis(
    McpToolExecutorRegistry toolRegistry) async {
  logInfo("Performing initial project analysis...", component: "ANALYSIS");

  try {
    // Get project structure with caching
    try {
      await cacheManager.getDirectoryTreeWithCache(".");
      logInfo("Project structure cached and analyzed", component: "ANALYSIS");
    } catch (e) {
      logWarn(
          "Cached structure analysis failed, falling back to direct tool: $e",
          component: "ANALYSIS");
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
      logInfo("Dependencies cached and analyzed", component: "ANALYSIS");
    } catch (e) {
      logWarn("Cached pubspec analysis failed, falling back to direct tool: $e",
          component: "ANALYSIS");
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

    logInfo("Project structure analyzed", component: "ANALYSIS");
    logInfo("Dependencies identified", component: "ANALYSIS");
  } catch (e) {
    logWarn("Initial analysis limited: $e", component: "ANALYSIS");
    logInfo("Proceeding with standard coding assistance...",
        component: "ANALYSIS");
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
  print("\n🔧 LOGGING CONTROL:");
  print("  Set environment variables to control output verbosity:");
  print("  - MCP_DEBUG=true - Show detailed MCP communication");
  print("  - MCP_LOG_LEVEL=debug|info|warn|error|none");
  print("  - Default: Clean, minimal output with tool justifications");
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
      logInfo("All caches cleared", component: "CACHE");
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

      logInfo("Session terminated", component: "MAIN");
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
      logError("Analysis failed: $e", component: "AGENT");
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
