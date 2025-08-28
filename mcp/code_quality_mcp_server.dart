import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';

/// 🔍 CODE QUALITY MCP SERVER: Code Analysis and Quality Assurance
/// 
/// Provides comprehensive code quality analysis for Dart projects including:
/// - Lint analysis using dart analyze
/// - Security vulnerability scanning  
/// - Code complexity metrics
/// - Performance profiling
/// - Dependency analysis
/// 
/// Implementation follows a phased approach:
/// - Phase 1: Basic linting integration ✅
/// - Phase 2: Security vulnerability scanning
/// - Phase 3: Code complexity analysis  
/// - Phase 4: Performance & dependency analysis
/// - Phase 5: Integration & polish
class CodeQualityMCPServer extends BaseMCPServer {
  final bool enableDebugLogging;
  final Duration executionTimeout;
  final String workingDirectory;
  final Map<String, dynamic> qualityConfig;

  CodeQualityMCPServer({
    super.name = 'code-quality',
    super.version = '1.0.0',
    super.logger,
    this.enableDebugLogging = false,
    this.executionTimeout = const Duration(minutes: 2),
    this.workingDirectory = '.',
    this.qualityConfig = const {},
  });

  @override
  Future<void> initializeServer() async {
    _logDebug('🚀 Initializing Code Quality MCP Server...');
    
    // Phase 1: Basic linting integration
    _registerLintAnalysisTools();
    
    // Future phases will be added incrementally
    // TODO: Phase 2 - Security vulnerability scanning
    // TODO: Phase 3 - Code complexity analysis  
    // TODO: Phase 4 - Performance & dependency analysis
    // TODO: Phase 5 - Integration & reporting
    
    _logDebug('✅ Code Quality MCP Server initialized');
  }

  /// 📋 PHASE 1: Register linting analysis tools
  void _registerLintAnalysisTools() {
    // Main lint analysis tool
    registerTool(MCPTool(
      name: 'run_lint_analysis',
      description: 'Analyze Dart code using dart analyze and return structured results',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Path to analyze (file or directory)',
            'default': '.',
          },
          'include_info': {
            'type': 'boolean', 
            'description': 'Include info-level issues (like missing docs)',
            'default': false,
          },
          'format': {
            'type': 'string',
            'enum': ['json', 'text', 'github'],
            'description': 'Output format for results',
            'default': 'json',
          }
        }
      },
      callback: _runLintAnalysis,
    ));

    // Quick lint check tool
    registerTool(MCPTool(
      name: 'quick_lint_check',
      description: 'Quick lint check for errors and warnings only',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Path to check',
            'default': '.',
          }
        }
      },
      callback: _quickLintCheck,
    ));
  }

  /// 🔍 PHASE 1: Run comprehensive lint analysis
  Future<MCPToolResult> _runLintAnalysis(Map<String, dynamic> args) async {
    try {
      final path = args['path'] as String? ?? '.';
      final includeInfo = args['include_info'] as bool? ?? false;
      final format = args['format'] as String? ?? 'json';
      
      _logDebug('🔍 Running lint analysis on: $path');
      
      // Validate path exists
      final pathExists = Directory(path).existsSync() || File(path).existsSync();
      if (!pathExists) {
        return MCPToolResult(content: [
          MCPContent.text(jsonEncode({
            'success': false,
            'error': 'Path does not exist: $path'
          }))
        ]);
      }

      // Build dart analyze command
      final List<String> command = [
        'dart', 
        'analyze',
      ];

      // Add format flags
      if (!includeInfo) {
        // Don't treat info-level issues as fatal (they'll still show but won't cause exit code != 0)
        // Note: We can't filter them out entirely, but we can control fatality
        // The filtering happens in our parsing logic instead
      }
      
      command.add(path);

      // Execute dart analyze
      final stopwatch = Stopwatch()..start();
      final result = await Process.run(
        command.first,
        command.sublist(1),
        workingDirectory: workingDirectory,
        runInShell: true,
      ).timeout(executionTimeout);
      
      stopwatch.stop();

      // Log any stderr errors
      if (result.stderr.toString().isNotEmpty) {
        _logDebug('⚠️ Process stderr: "${result.stderr}"');
      }

      // Parse results based on format
      final analysisResult = await _parseLintResults(
        result, 
        path, 
        format,
        stopwatch.elapsedMilliseconds,
        includeInfo,
      );

      _logDebug('✅ Lint analysis completed in ${stopwatch.elapsedMilliseconds}ms');
      
      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'data': analysisResult
        }))
      ]);
      
    } catch (e) {
      _logDebug('❌ Lint analysis failed: $e');
      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': false,
          'error': 'Lint analysis failed: $e'
        }))
      ]);
    }
  }

  /// ⚡ PHASE 1: Quick lint check for errors/warnings only
  Future<MCPToolResult> _quickLintCheck(Map<String, dynamic> args) async {
    try {
      final path = args['path'] as String? ?? '.';
      
      _logDebug('⚡ Running quick lint check on: $path');
      
      final result = await Process.run(
        'dart',
        ['analyze', path],
        workingDirectory: workingDirectory,
        runInShell: true,
      ).timeout(const Duration(seconds: 30));

      final hasIssues = result.exitCode != 0;
      final issueCount = result.stdout.toString().split('\n')
          .where((line) => line.trim().isNotEmpty && !line.startsWith('Analyzing'))
          .length;

      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'data': {
            'status': hasIssues ? 'issues_found' : 'clean',
            'exit_code': result.exitCode,
            'issue_count': issueCount,
            'summary': hasIssues 
                ? 'Found $issueCount issues in $path'
                : 'No issues found in $path',
            'has_errors': result.exitCode != 0,
          }
        }))
      ]);
      
    } catch (e) {
      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': false,
          'error': 'Quick lint check failed: $e'
        }))
      ]);
    }
  }

  /// 📊 PHASE 1: Parse dart analyze results into structured format
  Future<Map<String, dynamic>> _parseLintResults(
    ProcessResult result,
    String path,
    String format,
    int executionTimeMs,
    bool includeInfo,
  ) async {
    final output = result.stdout.toString();
    final errorOutput = result.stderr.toString();
    
    // Parse issues from output
    final allIssues = _parseIssuesFromOutput(output);
    
    // Filter issues based on includeInfo setting
    final issues = includeInfo 
        ? allIssues 
        : allIssues.where((issue) => issue['severity'] != 'info').toList();
    
    // Count by severity from all issues (before filtering for display)
    final errorCount = allIssues.where((i) => i['severity'] == 'error').length;
    final warningCount = allIssues.where((i) => i['severity'] == 'warning').length;
    final infoCount = allIssues.where((i) => i['severity'] == 'info').length;

    final baseResult = {
      'analysis_path': path,
      'execution_time_ms': executionTimeMs,
      'exit_code': result.exitCode,
      'total_issues': issues.length,
      'error_count': errorCount,
      'warning_count': warningCount, 
      'info_count': infoCount,
      'status': result.exitCode == 0 ? 'clean' : 'issues_found',
      'issues': issues,
    };

    // Add stderr if there were execution errors
    if (errorOutput.isNotEmpty) {
      baseResult['execution_errors'] = errorOutput;
    }

    // Format based on request
    switch (format) {
      case 'github':
        return _formatForGitHub(baseResult);
      case 'text':
        return _formatAsText(baseResult);
      default:
        return baseResult;
    }
  }

  /// 📝 Parse individual issues from dart analyze output
  /// Format: "severity - file:line:column - message - rule"
  List<Map<String, dynamic>> _parseIssuesFromOutput(String output) {
    final issues = <Map<String, dynamic>>[];
    final lines = output.split('\n');
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty || 
          trimmedLine.startsWith('Analyzing') ||
          trimmedLine.endsWith('issues found.') ||
          trimmedLine.contains('No issues found')) {
        continue;
      }
      
      // Parse format: "severity - file:line:column - message - rule"
      // Example: "  error - test.dart:1:37 - Expected to find ';'. - expected_token"
      final match = RegExp(r'^\s*(error|warning|info)\s+-\s+(.+?):(\d+):(\d+)\s+-\s+(.+?)\s+-\s+(.+?)$')
          .firstMatch(trimmedLine);
      
      if (match != null) {
        final severity = match.group(1)!.toLowerCase();
        final file = match.group(2)!;
        final line = int.tryParse(match.group(3)!) ?? 0;
        final column = int.tryParse(match.group(4)!) ?? 0;
        final message = match.group(5)!;
        final rule = match.group(6)!;
        
        issues.add({
          'severity': severity,
          'message': message,
          'file': file,
          'line': line,
          'column': column,
          'rule': rule,
          'location': '$file:$line:$column',
        });
      }
    }
    
    return issues;
  }

  /// 📋 Format results for GitHub Actions
  Map<String, dynamic> _formatForGitHub(Map<String, dynamic> result) {
    final issues = result['issues'] as List<Map<String, dynamic>>;
    final annotations = issues.map((issue) => {
      'path': issue['file'],
      'start_line': issue['line'],
      'end_line': issue['line'],
      'start_column': issue['column'],
      'end_column': issue['column'],
      'annotation_level': _severityToGitHubLevel(issue['severity'] as String),
      'message': issue['message'],
      'title': issue['rule'] ?? 'Lint Issue',
    }).toList();

    return {
      ...result,
      'format': 'github',
      'annotations': annotations,
    };
  }

  /// 📄 Format results as readable text
  Map<String, dynamic> _formatAsText(Map<String, dynamic> result) {
    final issues = result['issues'] as List<Map<String, dynamic>>;
    final buffer = StringBuffer();
    
    buffer.writeln('📊 Code Quality Analysis Results');
    buffer.writeln('================================');
    buffer.writeln('Path: ${result['analysis_path']}');
    buffer.writeln('Status: ${result['status']}');
    buffer.writeln('Total Issues: ${result['total_issues']}');
    buffer.writeln('  - Errors: ${result['error_count']}');
    buffer.writeln('  - Warnings: ${result['warning_count']}');
    buffer.writeln('  - Info: ${result['info_count']}');
    buffer.writeln('Execution Time: ${result['execution_time_ms']}ms');
    buffer.writeln('');

    if (issues.isNotEmpty) {
      buffer.writeln('🔍 Issues Found:');
      buffer.writeln('================');
      for (final issue in issues) {
        final severity = issue['severity'].toString().toUpperCase();
        buffer.writeln('[$severity] ${issue['message']}');
        buffer.writeln('  📍 ${issue['location']}');
        if (issue['rule'] != null) {
          buffer.writeln('  📏 Rule: ${issue['rule']}');
        }
        buffer.writeln('');
      }
    }

    return {
      ...result,
      'format': 'text',
      'formatted_output': buffer.toString(),
    };
  }

  /// 🏷️ Convert severity to GitHub annotation level
  String _severityToGitHubLevel(String severity) {
    switch (severity.toLowerCase()) {
      case 'error':
        return 'failure';
      case 'warning':
        return 'warning';
      case 'info':
        return 'notice';
      default:
        return 'notice';
    }
  }

  /// 🐛 Debug logging helper
  void _logDebug(String message) {
    if (enableDebugLogging) {
      print('🔍 [CodeQuality] $message');
    }
  }
}