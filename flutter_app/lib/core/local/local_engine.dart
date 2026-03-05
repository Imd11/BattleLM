import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'asset_bridge.dart';

sealed class EngineEvent {
  const EngineEvent();
}

class EngineTextDelta extends EngineEvent {
  final String delta;
  const EngineTextDelta(this.delta);
}

class EngineInfo extends EngineEvent {
  final String message;
  const EngineInfo(this.message);
}

class EngineDone extends EngineEvent {
  const EngineDone();
}

class EngineError extends EngineEvent {
  final String message;
  const EngineError(this.message);
}

class LocalEngine {
  Future<Stream<EngineEvent>> runOnce({
    required AIInstance ai,
    required String prompt,
  }) async {
    switch (ai.type) {
      case AIType.claude:
        return _runClaudeCode(prompt: prompt, cwd: ai.workingDirectory, model: ai.selectedModel);
      case AIType.codex:
        return _runCodexCli(prompt: prompt, cwd: ai.workingDirectory);
      case AIType.gemini:
        return _runGeminiCli(prompt: prompt, cwd: ai.workingDirectory, model: ai.selectedModel);
      case AIType.qwen:
        return _runQwenCli(prompt: prompt, cwd: ai.workingDirectory, model: ai.selectedModel);
      case AIType.kimi:
        return Stream.value(const EngineError('Kimi backend not wired yet for standalone desktop.'));
    }
  }

  Stream<EngineEvent> _runClaudeCode({required String prompt, required String cwd, String? model}) {
    // Prefer Claude Code CLI if installed (same philosophy as mac version: use user's local setup).
    final args = <String>[
      '-p',
      prompt,
      '--output-format',
      'stream-json',
      '--include-partial-messages',
      '--yolo',
    ];
    if ((model ?? '').trim().isNotEmpty) {
      args.addAll(['--model', model!.trim()]);
    }
    return _runStreamJsonCli(executable: 'claude', args: args, cwd: cwd);
  }

  Stream<EngineEvent> _runCodexCli({required String prompt, required String cwd}) {
    final ctrl = StreamController<EngineEvent>();

    () async {
      try {
        final proc = await Process.start(
          'codex',
          ['exec', prompt, '--json', '--full-auto', '--skip-git-repo-check'],
          workingDirectory: _normalizeCwd(cwd),
          runInShell: true,
        );

        final stdoutLines = proc.stdout.transform(utf8.decoder).transform(const LineSplitter());
        await for (final line in stdoutLines) {
          final evt = _parseCodexEvent(line);
          if (evt == null) continue;
          ctrl.add(evt);
        }

        final exitCode = await proc.exitCode;
        if (exitCode != 0) {
          final stderrText = await proc.stderr.transform(utf8.decoder).join();
          ctrl.add(EngineError(stderrText.isEmpty ? 'Codex exited with code $exitCode' : stderrText.trim()));
        } else {
          ctrl.add(const EngineDone());
        }
      } catch (e) {
        ctrl.add(EngineError(_formatStartError(executable: 'codex', error: e)));
      } finally {
        await ctrl.close();
      }
    }();

    return ctrl.stream;
  }

  Stream<EngineEvent> _runGeminiCli({required String prompt, required String cwd, String? model}) {
    // Mirrors mac headless args: stream-json + no sandbox + yolo (user-controlled via their local gemini config).
    final args = <String>[
      prompt,
      '--output-format',
      'stream-json',
      '--sandbox',
      'false',
      '--yolo',
    ];
    if ((model ?? '').trim().isNotEmpty) {
      args.addAll(['--model', model!.trim()]);
    }
    return _runStreamJsonCli(executable: 'gemini', args: args, cwd: cwd);
  }

  Stream<EngineEvent> _runQwenCli({required String prompt, required String cwd, String? model}) {
    final args = <String>[
      '-p',
      prompt,
      '--output-format',
      'stream-json',
      '--include-partial-messages',
      '--yolo',
    ];
    if ((model ?? '').trim().isNotEmpty) {
      args.addAll(['--model', model!.trim()]);
    }
    return _runStreamJsonCli(executable: 'qwen', args: args, cwd: cwd);
  }

  EngineEvent? _parseCodexEvent(String jsonLine) {
    try {
      final obj = jsonDecode(jsonLine);
      if (obj is! Map<String, dynamic>) return null;
      final type = obj['type'];
      if (type is! String) return null;

      switch (type) {
        case 'message.delta':
          final content = obj['content'];
          if (content is String && content.isNotEmpty) return EngineTextDelta(content);
          final delta = obj['delta'];
          if (delta is Map && delta['text'] is String && (delta['text'] as String).isNotEmpty) {
            return EngineTextDelta(delta['text'] as String);
          }
          return null;
        case 'message.completed':
          final content = obj['content'];
          if (content is String && content.isNotEmpty) return EngineTextDelta(content);
          return const EngineDone();
        case 'response.completed':
          return const EngineDone();
        case 'error':
          final msg = (obj['message'] as String?) ?? 'Codex error';
          return EngineError(msg);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  Stream<EngineEvent> _runStreamJsonCli({
    required String executable,
    required List<String> args,
    required String cwd,
  }) {
    final ctrl = StreamController<EngineEvent>();

    () async {
      Process? proc;
      final parser = _ClaudeLikeJsonParser();
      try {
        proc = await Process.start(
          executable,
          args,
          workingDirectory: _normalizeCwd(cwd),
          runInShell: true,
        );

        final stdoutLines = proc.stdout.transform(utf8.decoder).transform(const LineSplitter());
        await for (final line in stdoutLines) {
          for (final evt in parser.parseLine(line)) {
            ctrl.add(evt);
          }
        }

        final exitCode = await proc.exitCode;
        if (exitCode != 0) {
          final stderrText = await proc.stderr.transform(utf8.decoder).join();
          ctrl.add(EngineError(stderrText.isEmpty ? '$executable exited with code $exitCode' : stderrText.trim()));
        } else {
          ctrl.add(const EngineDone());
        }
      } catch (e) {
        ctrl.add(EngineError(_formatStartError(executable: executable, error: e)));
      } finally {
        if (proc != null) {
          try {
            proc.kill();
          } catch (_) {}
        }
        await ctrl.close();
      }
    }();

    return ctrl.stream;
  }

  Stream<EngineEvent> _runNodeBridge({
    required String bridgeAsset,
    required Map<String, dynamic> request,
  }) {
    final ctrl = StreamController<EngineEvent>();

    () async {
      Process? proc;
      try {
        final bridgeFile = await AssetBridge.shared.ensureExtracted(bridgeAsset);
        proc = await Process.start(
          'node',
          [bridgeFile.path],
          runInShell: true,
        );

        proc.stdin.writeln(jsonEncode(request));
        await proc.stdin.flush();
        await proc.stdin.close();

        final lines = proc.stdout.transform(utf8.decoder).transform(const LineSplitter());
        await for (final line in lines) {
          final evt = _parseBridgeEvent(line);
          if (evt != null) ctrl.add(evt);
        }

        final exitCode = await proc.exitCode;
        if (exitCode != 0) {
          final err = await proc.stderr.transform(utf8.decoder).join();
          ctrl.add(EngineError(err.isEmpty ? 'Bridge exited with code $exitCode' : err.trim()));
        } else {
          ctrl.add(const EngineDone());
        }
      } catch (e) {
        ctrl.add(EngineError('Failed to run node bridge: $e'));
      } finally {
        if (proc != null) {
          try {
            proc.kill();
          } catch (_) {}
        }
        await ctrl.close();
      }
    }();

    return ctrl.stream;
  }

  EngineEvent? _parseBridgeEvent(String jsonLine) {
    try {
      final obj = jsonDecode(jsonLine);
      if (obj is! Map<String, dynamic>) return null;
      final type = obj['type'];
      if (type is! String) return null;
      switch (type) {
        case 'text_delta':
          final c = obj['content'];
          if (c is String && c.isNotEmpty) return EngineTextDelta(c);
          return null;
        case 'done':
          return const EngineDone();
        case 'error':
          final c = obj['content'];
          return EngineError(c is String ? c : 'Bridge error');
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  String? _normalizeCwd(String cwd) {
    final trimmed = cwd.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == '~' || trimmed.startsWith('~/') || trimmed.startsWith('~\\')) {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          (Platform.environment['HOMEDRIVE'] != null && Platform.environment['HOMEPATH'] != null
              ? '${Platform.environment['HOMEDRIVE']}${Platform.environment['HOMEPATH']}'
              : null);
      if (home == null || home.isEmpty) return null;
      if (trimmed == '~') return home;
      final rest = trimmed.substring(1);
      return home + rest;
    }
    return trimmed;
  }

  String _formatStartError({required String executable, required Object error}) {
    final hint = _installHint(executable);
    if (error is ProcessException) {
      final msg = (error.message).trim();
      if (msg.isEmpty) return hint;
      return '$msg\n$hint';
    }
    return 'Failed to start $executable: $error\n$hint';
  }

  String _installHint(String executable) {
    switch (executable) {
      case 'claude':
        return 'Tip: ensure Claude Code is installed and on PATH (e.g. `npm i -g @anthropic-ai/claude-code`)';
      case 'codex':
        return 'Tip: ensure Codex CLI is installed and on PATH.';
      case 'gemini':
        return 'Tip: ensure Gemini CLI is installed and on PATH.';
      case 'qwen':
        return 'Tip: ensure Qwen Code CLI is installed and on PATH (e.g. `npm i -g @qwen-code/qwen-code@latest`)';
      default:
        return 'Tip: ensure `$executable` is installed and on PATH.';
    }
  }
}

class _ClaudeLikeJsonParser {
  int _assistantCharsSent = 0;

  Iterable<EngineEvent> parseLine(String line) sync* {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) return;

    try {
      final obj = jsonDecode(trimmed);
      if (obj is! Map<String, dynamic>) return;
      final type = obj['type'];
      if (type is! String) return;

      switch (type) {
        case 'stream_event':
          final event = obj['event'];
          if (event is Map && event['type'] == 'content_block_delta') {
            final delta = event['delta'];
            if (delta is Map) {
              if (delta['type'] == 'text_delta' && delta['text'] is String) {
                final text = (delta['text'] as String);
                if (text.isNotEmpty) {
                  _assistantCharsSent += text.length;
                  yield EngineTextDelta(text);
                }
              } else if (delta['type'] == 'thinking_delta' && delta['thinking'] is String) {
                final think = (delta['thinking'] as String);
                if (think.isNotEmpty) yield EngineInfo(think);
              }
            }
          }
          return;

        case 'assistant':
          final msg = obj['message'];
          if (msg is Map) {
            final content = msg['content'];
            if (content is List) {
              final buf = StringBuffer();
              for (final block in content) {
                if (block is Map && block['type'] == 'text' && block['text'] is String) {
                  buf.write(block['text'] as String);
                }
              }
              final full = buf.toString();
              if (full.isEmpty) return;
              if (full.length > _assistantCharsSent) {
                final delta = full.substring(_assistantCharsSent);
                _assistantCharsSent = full.length;
                if (delta.isNotEmpty) yield EngineTextDelta(delta);
              }
            }
          }
          return;

        case 'result':
          yield const EngineDone();
          return;

        case 'error':
          final msg = (obj['error'] as String?) ?? (obj['message'] as String?) ?? 'CLI error';
          yield EngineError(msg);
          return;

        case 'info':
          final msg = (obj['content'] as String?) ?? '';
          if (msg.isNotEmpty) yield EngineInfo(msg);
          return;

        case 'system':
          return;

        default:
          return;
      }
    } catch (_) {
      // Fallback: treat non-JSON output as plain text.
      yield EngineTextDelta('$trimmed\n');
    }
  }
}
