# Dart AI Coding Assistant

A dedicated AI-powered coding assistant for Dart development, providing professional code analysis, refactoring recommendations, and architectural guidance.

## Features

- **Code Analysis**: Comprehensive Dart code examination and quality assessment
- **Architectural Guidance**: Modern Dart architecture patterns and best practices
- **Refactoring Support**: Actionable recommendations for code improvement
- **MCP Integration**: Multiple Model Context Protocol servers for development operations
- **Interactive Workflow**: Terminal-based interface for coding assistance

## MCP Servers

- **Dart Development Server**: Code analysis, fixing, and execution
- **Terminal Command Server**: Secure local system command execution
- **Context Manager Server**: Intelligent context optimization and session management
- **Puppeteer Server**: Web automation and scraping capabilities
- **Filesystem Server**: File operations and project structure analysis

## Quick Start

1. **Set up API key**:
   ```bash
   export DEEPSEEK_API_KEY=your_api_key_here
   ```

2. **Install dependencies**:
   ```bash
   dart pub get
   ```

3. **Run the coding assistant**:
   ```bash
   dart run bin/ai_coding_assistant.dart
   ```

## Usage

The AI coding assistant provides interactive code analysis:

```
analyze <file/dir>    - Code analysis
review <file>         - Code review
arch <topic>          - Architectural guidance
refactor <file>       - Refactoring recommendations
exit/quit/done        - End session
```

## Project Structure

```
dart-ai-coding-assistant/
├── bin/                 # Executable files
│   ├── ai_coding_assistant.dart
│   └── coding_assistant_tips.txt
├── config/              # Configuration files
│   └── mcp_servers.json
├── mcp/                 # MCP server implementations
│   ├── mcp_server_context_manager.dart
│   ├── mcp_server_dart.dart
│   ├── mcp_server_puppeteer.dart
│   └── mcp_server_terminal.dart
├── lib/                 # Shared utilities and libraries
└── test/               # Test suite
```

## Dependencies

- `dart_openai_client`: Local OpenAI-compatible API client
- `puppeteer`: Web automation and scraping
- `path`: Path manipulation utilities

## Development

This project is designed as a clean, focused coding assistant without accounting-specific functionality. It leverages the same core MCP infrastructure but is specialized for software development tasks.

## License

MIT License - see LICENSE file for details.

---

*Part of the Dart AI Development Toolkit*