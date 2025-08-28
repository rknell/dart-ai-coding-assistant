#!/usr/bin/env dart

/// Test runner script for dart-ai-coding-assistant
library;
/// 
/// Provides fast test execution with different categories:
/// - unit: Fast unit tests for development feedback
/// - component: Component tests with minimal dependencies  
/// - integration: Tests requiring MCP servers
/// - slow: Comprehensive end-to-end tests
/// - all: Complete test suite
/// 
/// Usage:
///   dart test_runner.dart [category] [options]
///   dart test_runner.dart unit
///   dart test_runner.dart integration --verbose
///   dart test_runner.dart coverage

import 'dart:io';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    printUsage();
    exit(1);
  }

  final category = args[0];
  final verbose = args.contains('--verbose') || args.contains('-v');
  final watch = args.contains('--watch') || args.contains('-w');

  // Load test configuration
  final config = await loadConfig();
  if (!config.containsKey(category)) {
    print('❌ Unknown test category: $category');
    print('Available categories: ${config.keys.join(', ')}');
    exit(1);
  }

  final categoryConfig = config[category] as YamlMap;
  
  if (verbose) {
    print('🏃 Running $category tests: ${categoryConfig['description']}');
    print('📁 Max duration: ${categoryConfig['max_duration'] ?? 'unlimited'}');
    print('🔀 Concurrency: ${categoryConfig['concurrency'] ?? 'default'}');
  }

  await runTests(categoryConfig, verbose: verbose, watch: watch);
}

Future<YamlMap> loadConfig() async {
  final configFile = File('test_config.yaml');
  if (!configFile.existsSync()) {
    print('❌ test_config.yaml not found');
    exit(1);
  }

  final content = await configFile.readAsString();
  return loadYaml(content) as YamlMap;
}

Future<void> runTests(YamlMap config, {bool verbose = false, bool watch = false}) async {
  final List<String> command = ['dart', 'test'];
  
  // Add includes
  if (config['includes'] != null) {
    for (final include in config['includes'] as YamlList) {
      command.add(include.toString());
    }
  }

  // Add concurrency
  if (config['concurrency'] != null) {
    command.addAll(['--concurrency', config['concurrency'].toString()]);
  }

  // Add timeout
  if (config['timeout'] != null) {
    command.addAll(['--timeout', config['timeout'].toString()]);
  }

  // Add tags
  if (config['tags'] != null) {
    final tags = (config['tags'] as YamlList).join(' || ');
    command.addAll(['--tags', tags]);
  }

  // Add exclude tags
  if (config['exclude_tags'] != null) {
    final excludeTags = (config['exclude_tags'] as YamlList).join(' || ');
    command.addAll(['--exclude-tags', excludeTags]);
  }

  // Add coverage if specified
  if (config['coverage_output'] != null) {
    command.addAll(['--coverage', config['coverage_output'].toString()]);
  }

  // Add reporter based on verbosity
  if (verbose) {
    command.addAll(['--reporter', 'expanded']);
  } else {
    command.addAll(['--reporter', 'compact']);
  }

  // Add watch mode if requested
  if (watch) {
    print('👀 Running in watch mode (not natively supported by dart test)');
    print('💡 Consider using: dart run test --watch when available');
  }

  if (verbose) {
    print('🔧 Command: ${command.join(' ')}');
    print('');
  }

  // Start timer for performance tracking
  final stopwatch = Stopwatch()..start();

  final process = await Process.start(command[0], command.skip(1).toList());
  
  // Forward stdout and stderr
  process.stdout.listen((data) {
    stdout.add(data);
  });
  
  process.stderr.listen((data) {
    stderr.add(data);
  });

  final exitCode = await process.exitCode;
  stopwatch.stop();

  // Print summary
  final duration = stopwatch.elapsed;
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  final milliseconds = duration.inMilliseconds % 1000;

  print('');
  if (exitCode == 0) {
    print('✅ Tests completed successfully in ${minutes}m $seconds.${milliseconds}s');
  } else {
    print('❌ Tests failed in ${minutes}m $seconds.${milliseconds}s');
  }

  // Performance warnings
  final maxDuration = config['max_duration']?.toString() ?? '';
  if (maxDuration.isNotEmpty && maxDuration != 'unlimited') {
    final maxSeconds = _parseDuration(maxDuration);
    if (duration.inSeconds > maxSeconds) {
      print('⚠️  Tests exceeded expected duration of $maxDuration');
      print('💡 Consider optimizing slow tests or moving them to a different category');
    }
  }

  exit(exitCode);
}

int _parseDuration(String duration) {
  if (duration.endsWith('s')) {
    return int.parse(duration.substring(0, duration.length - 1));
  } else if (duration.endsWith('m')) {
    return int.parse(duration.substring(0, duration.length - 1)) * 60;
  }
  return 30; // default
}

void printUsage() {
  print('🧪 Dart AI Coding Assistant Test Runner');
  print('');
  print('Usage: dart test_runner.dart <category> [options]');
  print('');
  print('Categories:');
  print('  unit        Fast unit tests for development feedback (< 10s)');
  print('  component   Component tests with minimal dependencies (< 30s)');
  print('  integration Integration tests with MCP servers (< 2m)');  
  print('  slow        Comprehensive slow integration tests (< 5m)');
  print('  all         Complete test suite for CI/CD');
  print('  coverage    Tests with coverage reporting');
  print('');
  print('Options:');
  print('  -v, --verbose   Verbose output with expanded reporting');
  print('  -w, --watch     Watch mode (where supported)');
  print('');
  print('Examples:');
  print('  dart test_runner.dart unit');
  print('  dart test_runner.dart integration --verbose');
  print('  dart test_runner.dart coverage');
  print('');
  print('For development, use "unit" tests for fast feedback.');
  print('For comprehensive testing, use "all" or run categories sequentially.');
}