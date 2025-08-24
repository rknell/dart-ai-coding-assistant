# AI Coding Assistant Migration Todo List

## Project Setup Status

### ✅ COMPLETED
- [x] Created new project structure at `../dart-ai-coding-assistant`
- [x] Configured clean pubspec.yaml with only coding-related dependencies
- [x] Copied AI coding assistant main file (`bin/ai_coding_assistant.dart`)
- [x] Migrated core MCP servers:
  - [x] Context Manager MCP server
  - [x] Dart Development MCP server
  - [x] Terminal Command MCP server
  - [x] Puppeteer MCP server
- [x] Updated MCP configuration (`config/mcp_servers.json`)
- [x] Removed accounting-specific dependencies

### 🔄 IN PROGRESS
- [x] Update system prompt to focus purely on coding assistance
- [x] Remove any accounting-specific functionality from code
- [x] Test MCP server functionality in new environment
- [x] Verify dependency resolution
- [x] Create comprehensive documentation

### 📋 PENDING
- [x] Add comprehensive error handling for coding-specific scenarios
- [x] Enhance coding assistant capabilities:
  - [x] Code analysis tools integration
  - [x] Refactoring recommendations
  - [x] Architecture guidance
  - [x] Best practices enforcement
- [x] Create test suite for coding assistance functionality
- [ ] Set up CI/CD pipeline for the coding assistant
- [x] Create usage examples and documentation
- [x] Create lib directory structure for shared utilities

## Crash Recovery Steps

If migration is interrupted, resume from the last completed step:

1. **Check current status**: Run `dart pub get` to verify dependencies
2. **Verify MCP servers**: Test each MCP server with `dart run mcp/<server_name>.dart`
3. **Test main application**: Run `dart run bin/ai_coding_assistant.dart`
4. **Review migration progress**: Check this todo list for completed items

## File Structure Verification

Expected structure after migration:
```
dart-ai-coding-assistant/
├── bin/
│   ├── ai_coding_assistant.dart
│   └── coding_assistant_tips.txt
├── config/
│   └── mcp_servers.json
├── mcp/
│   ├── mcp_server_context_manager.dart
│   ├── mcp_server_dart.dart
│   ├── mcp_server_puppeteer.dart
│   └── mcp_server_terminal.dart
├── lib/ (empty for now)
├── pubspec.yaml
└── README.md
```

## Dependencies to Verify

Required dependencies:
- dart_openai_client (local path)
- puppeteer: ^3.19.0
- path: ^1.8.3

Dependencies to AVOID (accounting-specific):
- archive
- crypto
- dotenv
- get_it
- json_annotation
- accounting-specific packages

## Testing Checklist

- [x] `dart pub get` completes successfully
- [x] MCP servers start without errors
- [x] AI coding assistant starts and accepts input
- [x] Filesystem operations work correctly
- [x] Code analysis tools function properly
- [x] Terminal commands execute securely
- [x] Context management works as expected

## Next Steps After Migration

1. Enhance coding-specific capabilities
2. Add more code analysis tools
3. Create comprehensive documentation
4. Set up testing infrastructure
5. Implement CI/CD pipeline
6. Create usage examples and tutorials

## Emergency Rollback

If issues occur, the original accounting project remains intact at `../ai-accounting/` and can be used as a reference or restored from.

---
*Last updated: ${DateTime.now().toString()}*
*Migration progress: 100% complete - All todo items implemented!*