import 'dart:io';

/// 📊 PROJECT LOGGING CONFIGURATION: Centralized logging control
///
/// Provides consistent logging levels across all project components.
/// Controls output verbosity for MCP communication, tool execution, and system operations.
class LoggingConfig {
  /// 🔒 SINGLETON INSTANCE: Single source of truth for logging configuration
  static final LoggingConfig _instance = LoggingConfig._internal();

  /// 🏗️ FACTORY CONSTRUCTOR: Returns the singleton instance
  ///
  /// Ensures only one logging configuration exists across the entire application.
  /// Use this to access the centralized logging system.
  factory LoggingConfig() => _instance;

  /// 🔒 INTERNAL CONSTRUCTOR: Private constructor for singleton pattern
  LoggingConfig._internal();

  /// 📊 CURRENT LOG LEVEL: Controls output verbosity across the project
  late final LogLevel _logLevel;

  /// 🏗️ INITIALIZATION: Set up logging configuration from environment
  ///
  /// Must be called before using any logging functions.
  /// Reads environment variables to determine the appropriate log level.
  void initialize() {
    _logLevel = _determineLogLevel();
  }

  /// 🔍 DETERMINE LOG LEVEL: Check environment variables for logging control
  ///
  /// Supports multiple environment variable formats:
  /// - MCP_DEBUG=true or MCP_VERBOSE=true → debug level
  /// - MCP_LOG_LEVEL=debug|info|warn|error|none → specific level
  /// - Default: info level for clean, minimal output
  LogLevel _determineLogLevel() {
    final debugEnv = Platform.environment['MCP_DEBUG']?.toLowerCase();
    final verboseEnv = Platform.environment['MCP_VERBOSE']?.toLowerCase();

    if (debugEnv == 'true' || verboseEnv == 'true') {
      return LogLevel.debug;
    }

    final logLevelEnv = Platform.environment['MCP_LOG_LEVEL']?.toLowerCase();
    switch (logLevelEnv) {
      case 'debug':
        return LogLevel.debug;
      case 'info':
        return LogLevel.info;
      case 'warn':
        return LogLevel.warn;
      case 'error':
        return LogLevel.error;
      case 'none':
        return LogLevel.none;
      default:
        return LogLevel.info; // Default to clean, minimal output
    }
  }

  /// 📝 LOG MESSAGE: Output message based on current log level
  ///
  /// [level] - The log level for this message
  /// [message] - The message to display
  /// [data] - Optional additional data to append
  /// [component] - Optional component identifier for context
  ///
  /// Only outputs messages that meet or exceed the current log level threshold.
  /// Component identification helps organize logs by system component.
  void log(LogLevel level, String message, {Object? data, String? component}) {
    if (level.index >= _logLevel.index) {
      final componentPrefix = component != null ? '[$component] ' : '';
      final dataSuffix = data != null ? ' - $data' : '';

      switch (level) {
        case LogLevel.debug:
          print('🔍 DEBUG: $componentPrefix$message$dataSuffix');
          break;
        case LogLevel.info:
          print('ℹ️  $componentPrefix$message');
          break;
        case LogLevel.warn:
          print('⚠️  $componentPrefix$message');
          break;
        case LogLevel.error:
          print('❌ $componentPrefix$message');
          break;
        case LogLevel.none:
          // No output
          break;
      }
    }
  }

  /// 🎯 GET CURRENT LOG LEVEL: Access current logging configuration
  ///
  /// Returns the currently active log level that controls output verbosity.
  /// Useful for conditional logic based on logging configuration.
  LogLevel get currentLevel => _logLevel;

  /// 🔍 IS DEBUG MODE: Check if detailed logging is enabled
  ///
  /// Returns true if the current log level is debug, enabling detailed output.
  /// Useful for conditional debug-only code paths.
  bool get isDebugMode => _logLevel == LogLevel.debug;

  /// 📊 GET LOG LEVEL NAME: Human-readable log level name
  ///
  /// Returns a string representation of the current log level.
  /// Useful for display purposes and configuration reporting.
  String get levelName {
    switch (_logLevel) {
      case LogLevel.none:
        return 'none';
      case LogLevel.error:
        return 'error';
      case LogLevel.warn:
        return 'warn';
      case LogLevel.info:
        return 'info';
      case LogLevel.debug:
        return 'debug';
    }
  }
}

/// 📊 LOG LEVEL: Controls output verbosity for the entire project
///
/// Defines the hierarchy of logging levels from most restrictive (none) to most verbose (debug).
/// Higher levels include all lower levels in their output.
enum LogLevel {
  /// 🚫 NO OUTPUT: Complete silence, no logging whatsoever
  none,

  /// ❌ ERROR ONLY: Only critical error messages are displayed
  error,

  /// ⚠️  WARNINGS AND ERRORS: Warning messages and errors are displayed
  warn,

  /// ℹ️  INFO, WARNINGS, AND ERRORS: General information, warnings, and errors (default)
  info,

  /// 🔍 DEBUG: All output including detailed debug information
  debug,
}

/// 🚀 GLOBAL LOGGING INSTANCE: Easy access to logging configuration
///
/// Singleton instance that provides centralized logging control.
/// Use this to access logging functionality throughout the application.
final logging = LoggingConfig();

/// 📝 CONVENIENCE LOGGING FUNCTIONS: Quick access to common log levels
///
/// These functions provide easy access to logging without needing to access
/// the logging instance directly. They automatically handle log level filtering.

/// 🔍 LOG DEBUG MESSAGE: Output debug-level information
///
/// [message] - The debug message to display
/// [data] - Optional additional data for context
/// [component] - Optional component identifier
///
/// Only outputs when debug logging is enabled.
void logDebug(String message, {Object? data, String? component}) {
  logging.log(LogLevel.debug, message, data: data, component: component);
}

/// ℹ️  LOG INFO MESSAGE: Output general information
///
/// [message] - The informational message to display
/// [data] - Optional additional data for context
/// [component] - Optional component identifier
///
/// Outputs for info level and above (info, warn, error).
void logInfo(String message, {Object? data, String? component}) {
  logging.log(LogLevel.info, message, data: data, component: component);
}

/// ⚠️  LOG WARNING MESSAGE: Output warning information
///
/// [message] - The warning message to display
/// [data] - Optional additional data for context
/// [component] - Optional component identifier
///
/// Outputs for warn level and above (warn, error).
void logWarn(String message, {Object? data, String? component}) {
  logging.log(LogLevel.warn, message, data: data, component: component);
}

/// ❌ LOG ERROR MESSAGE: Output error information
///
/// [message] - The error message to display
/// [data] - Optional additional data for context
/// [component] - Optional component identifier
///
/// Always outputs regardless of log level (except none).
void logError(String message, {Object? data, String? component}) {
  logging.log(LogLevel.error, message, data: data, component: component);
}
