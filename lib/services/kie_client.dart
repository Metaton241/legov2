import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/detection.dart';
import '../models/lego_part.dart';
import 'image_service.dart';
import 'prompts.dart';

class KieException implements Exception {
  final String message;
  final String? rawResponse;
  KieException(this.message, {this.rawResponse});
  @override
  String toString() => 'KieException: $message';
}

class KieClient {
  final Dio _dio;
  final String _apiKey;
  final String _model;

  /// Models to fall back to (in order) when the primary returns
  /// "currently being maintained" or a transient gateway error.
  /// Cross-family is fine — _chat() picks the right endpoint per model.
  static const List<String> _fallbackChain = [
    'claude-sonnet-4-6',
    'claude-sonnet-4-5',
    'gemini-2.5-pro',
    'gemini-2.5-flash',
  ];

  bool _isClaude(String m) => m.startsWith('claude-');

  // Claude has tighter context limits — shrink images before sending.
  int _maxSideFor(String m) => _isClaude(m) ? 800 : 1280;
  int _qualityFor(String m) => _isClaude(m) ? 75 : 80;

  KieClient({
    required String apiKey,
    String baseUrl = 'https://api.kie.ai',
    String model = 'gemini-2.5-flash',
    Dio? dio,
  })  : _apiKey = apiKey,
        _model = model,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 120),
              receiveTimeout: const Duration(minutes: 6),
              responseType: ResponseType.json,
            ));

  Future<List<LegoPart>> parseInventory(File image) async {
    final b64 = await ImageService.compressAndEncode(
      image,
      maxSide: _maxSideFor(_model),
      quality: _qualityFor(_model),
    );
    final json = await _chat(Prompts.parseInventory, b64);
    final parts = (json['parts'] as List?) ?? const [];
    return parts
        .whereType<Map>()
        .map((m) => LegoPart.fromJson(m.cast<String, dynamic>()))
        .where((p) => p.partId.isNotEmpty)
        .toList();
  }

  Future<List<Detection>> findParts(File image, List<LegoPart> parts) async {
    final b64 = await ImageService.compressAndEncode(
      image,
      maxSide: _maxSideFor(_model),
      quality: _qualityFor(_model),
    );
    final partsJson = jsonEncode(parts.map((p) => p.toJson()).toList());
    final json = await _chat(Prompts.findParts(partsJson), b64);
    final dets = (json['detections'] as List?) ?? const [];
    final raw = dets
        .whereType<Map>()
        .map((m) => Detection.fromJson(m.cast<String, dynamic>()))
        .where((d) => d.partId.isNotEmpty && d.bbox.length == 4)
        .toList();
    return _dedup(raw);
  }

  /// Remove only obvious duplicates: if two boxes overlap more than 55% IoU,
  /// keep the higher-confidence one. Does NOT filter by color, qty, or
  /// confidence threshold — intentionally lenient.
  static List<Detection> _dedup(List<Detection> raw) {
    if (raw.length < 2) return raw;
    final sorted = [...raw]..sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <Detection>[];
    for (final d in sorted) {
      final clashes = kept.any((k) => _iou(d, k) > 0.55);
      if (!clashes) kept.add(d);
    }
    return kept;
  }

  static double _iou(Detection a, Detection b) {
    final ax2 = a.x + a.w, ay2 = a.y + a.h;
    final bx2 = b.x + b.w, by2 = b.y + b.h;
    final ix1 = a.x > b.x ? a.x : b.x;
    final iy1 = a.y > b.y ? a.y : b.y;
    final ix2 = ax2 < bx2 ? ax2 : bx2;
    final iy2 = ay2 < by2 ? ay2 : by2;
    final iw = ix2 - ix1;
    final ih = iy2 - iy1;
    if (iw <= 0 || ih <= 0) return 0.0;
    final inter = iw * ih;
    final union = a.w * a.h + b.w * b.h - inter;
    return union <= 0 ? 0.0 : inter / union;
  }

  Future<Map<String, dynamic>> _chat(String prompt, String imageBase64) async {
    // Try the primary model first; if kie.ai returns "currently being
    // maintained", auto-fallback to other models in the chain.
    final candidates = <String>[
      _model,
      ..._fallbackChain.where((m) => m != _model),
    ];
    Response? resp;
    String? lastErr;
    String? activeModel;
    for (final m in candidates) {
      activeModel = m;
      final isClaude = _isClaude(m);
      final path = isClaude ? '/claude/v1/messages' : '/$m/v1/chat/completions';
      final data = isClaude
          ? {
              'model': m,
              'max_tokens': 4096,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image',
                      'source': {
                        'type': 'base64',
                        'media_type': 'image/jpeg',
                        'data': imageBase64,
                      },
                    },
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
            }
          : {
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/jpeg;base64,$imageBase64',
                      },
                    },
                  ],
                },
              ],
              'stream': false,
            };

      try {
        resp = await _dio.post(
          path,
          options: Options(headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          }),
          data: data,
        );
      } on DioException catch (e) {
        // Auto-fallback on transient gateway/timeout errors as well —
        // 5xx (incl. Cloudflare 502/503/504/520-524) and connection timeouts.
        final code = e.response?.statusCode ?? 0;
        final isTransient = code >= 500 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        lastErr = code > 0
            ? 'kie.ai $m: HTTP $code (${e.message})'
            : 'kie.ai $m: ${e.message}';
        if (isTransient) {
          resp = null;
          continue;
        }
        throw KieException(lastErr, rawResponse: e.response?.data?.toString());
      }

      // kie.ai returns the maintenance error with HTTP 200 + envelope.
      final d = resp.data;
      if (d is Map &&
          d['code'] is num &&
          (d['code'] as num) >= 500 &&
          (d['msg']?.toString() ?? '').toLowerCase().contains('maintained')) {
        lastErr = 'kie.ai $m: ${d['msg']}';
        resp = null;
        continue; // try next model
      }
      break; // got a usable response
    }
    if (resp == null) {
      throw KieException(
          lastErr ?? 'kie.ai: все модели недоступны (попробуйте позже)');
    }

    dynamic data = resp.data;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        throw KieException(
          'Non-JSON response: ${data.length > 400 ? '${data.substring(0, 400)}…' : data}',
          rawResponse: data,
        );
      }
    }
    // kie.ai sometimes returns {"code": 4xx/5xx, "msg": "..."} with HTTP 200.
    if (data is Map && data['code'] is num && (data['code'] as num) >= 400) {
      throw KieException(
        'kie.ai: ${data['msg'] ?? 'unknown error'}',
        rawResponse: data.toString(),
      );
    }
    String? content;
    if (data is Map) {
      // Claude /messages: {content: [{type:"text", text:"..."}, ...]}
      if (activeModel != null && _isClaude(activeModel) && data['content'] is List) {
        final buf = StringBuffer();
        for (final b in (data['content'] as List)) {
          if (b is Map && b['type'] == 'text') {
            buf.write(b['text']?.toString() ?? '');
          }
        }
        content = buf.toString();
      } else if (data['choices'] is List &&
          (data['choices'] as List).isNotEmpty) {
        // OpenAI-compat /v1/chat/completions: {choices:[{message:{content:"..."}}]}
        content = (data['choices'][0]['message']?['content'])?.toString();
      }
    }
    if (content == null || content.isEmpty) {
      final preview = data?.toString() ?? '';
      throw KieException(
        'Empty content. Raw: ${preview.length > 400 ? '${preview.substring(0, 400)}…' : preview}',
        rawResponse: preview,
      );
    }
    return _extractJson(content);
  }

  static Map<String, dynamic> _extractJson(String content) {
    final trimmed = content.trim();
    // Try direct parse.
    try {
      final v = jsonDecode(trimmed);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}

    // Try to strip markdown fences ```json ... ```
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final m = fence.firstMatch(trimmed);
    if (m != null) {
      try {
        final v = jsonDecode(m.group(1)!);
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }

    // Try to grab the first {...} block.
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final v = jsonDecode(trimmed.substring(start, end + 1));
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }

    throw KieException('Response is not valid JSON', rawResponse: content);
  }
}
