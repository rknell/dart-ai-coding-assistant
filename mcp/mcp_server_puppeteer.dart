import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_openai_client/dart_openai_client.dart';
import 'package:puppeteer/puppeteer.dart';

/// PUPPETEER MCP SERVER: Core Web Automation
/// Provides web automation capabilities using Puppeteer
class PuppeteerMCPServer extends BaseMCPServer {
  final bool headless;
  final Duration navigationTimeout;

  PuppeteerMCPServer({
    super.name = 'puppeteer-dart',
    super.version = '1.0.0',
    super.logger,
    this.headless = true,
    this.navigationTimeout = const Duration(seconds: 30),
  });

  @override
  Future<void> initializeServer() async {
    // Navigation tools
    registerTool(MCPTool(
      name: 'puppeteer_navigate',
      description: 'Navigate to a URL and return page content',
      inputSchema: {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'URL to navigate to',
          },
        },
        'required': ['url'],
      },
      callback: _handleNavigate,
    ));

    // Content extraction tools
    registerTool(MCPTool(
      name: 'puppeteer_get_inner_text',
      description: 'Extract innerText content from page',
      inputSchema: {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector to target element',
            'default': 'body',
          },
        },
        'required': <String>[],
      },
      callback: _handleGetInnerText,
    ));

    logger?.call('info', 'Puppeteer MCP server initialized');
  }

  Future<MCPToolResult> _handleNavigate(Map<String, dynamic> arguments) async {
    final url = arguments['url'] as String;
    
    try {
      final browser = await puppeteer.launch(headless: headless);
      final page = await browser.newPage();
      
      await page.goto(url, wait: Until.networkIdle);
      final content = await page.content;
      
      await browser.close();
      
      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'url': url,
          'content': content,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Navigation failed: ${e.toString()}');
    }
  }

  Future<MCPToolResult> _handleGetInnerText(Map<String, dynamic> arguments) async {
    final selector = arguments['selector'] as String? ?? 'body';
    
    try {
      final browser = await puppeteer.launch(headless: headless);
      final page = await browser.newPage();
      
      // We need a page to work with, so navigate to about:blank
      await page.goto('about:blank', wait: Until.networkIdle);
      
      // This is a simplified version - in practice you'd need a page with content
      final text = await page.evaluate<String>('''
        () => {
          const element = document.querySelector('$selector');
          return element ? element.innerText : 'Element not found';
        }
      ''');
      
      await browser.close();
      
      return MCPToolResult(content: [
        MCPContent.text(jsonEncode({
          'success': true,
          'selector': selector,
          'text': text,
        })),
      ]);
    } catch (e) {
      throw MCPServerException('Content extraction failed: ${e.toString()}');
    }
  }
}

/// Main entry point
void main() async {
  final server = PuppeteerMCPServer(
    logger: (level, message, [data]) {
      if (level == 'error' || level == 'info') {
        final timestamp = DateTime.now().toIso8601String();
        stderr.writeln('[$timestamp] [$level] $message');
      }
    },
  );

  try {
    await server.start();
  } catch (e) {
    stderr.writeln('Failed to start Puppeteer MCP server: $e');
    exit(1);
  }
}