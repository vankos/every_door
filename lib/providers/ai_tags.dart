// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:every_door/providers/ai_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final aiTagsProvider = Provider((ref) => AiTagsProvider(ref));

/// An error while recognizing OSM tags from a photo with an AI model.
class AiTagsException implements Exception {
  /// True when the model replied with an empty tag set.
  final bool empty;

  final String message;

  AiTagsException(this.message, {this.empty = false});

  @override
  String toString() => message;
}

/// A photo to send to the AI model.
class AiPhoto {
  final Uint8List bytes;
  final String mimeType;

  const AiPhoto(this.bytes, this.mimeType);
}

class AiTagsProvider {
  static final _logger = Logger('AiTags');
  static const kEndpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const kTimeout = Duration(seconds: 120);

  static const kSystemPrompt = '''
You are an OpenStreetMap mapping assistant. The user sends one or more photos
of the same place (for example, the signboard with the name and the opening
hours), sometimes with a hint about what should be mapped there.
Return the OSM tags that best describe the object on the photos.

Rules:
- Reply with a single JSON object only, without markdown fences or explanations.
- Keys and values must be strings, for example: {"amenity": "cafe", "cuisine": "pizza"}.
- Use standard OSM keys and values: amenity=*, shop=*, tourism=*, leisure=*,
  craft=*, office=*, healthcare=*, man_made=*, building=*.
- Prefer the most specific main tag over a generic one.
- Combine the information from all the photos into a single tag set.
- Add the "name" tag only if the name is clearly readable in one of the photos.
- Add other tags (opening_hours, cuisine, brand, ...) only if you are sure about them.
- Do not invent details that are not visible. When in doubt, omit the tag.
- If the user hint is present, it has priority when the photos are ambiguous.
- If you cannot identify any object, return {}.
''';

  final Ref _ref;

  AiTagsProvider(this._ref);

  /// Sends the photos (and an optional user hint) to the AI model
  /// and returns the OSM tags it suggested for the object.
  Future<Map<String, String>> recognizeTags({
    required List<AiPhoto> photos,
    String? explanation,
  }) async {
    final settings = _ref.read(aiSettingsProvider);
    if (!settings.isConfigured) {
      throw AiTagsException('OpenRouter API key or model is not set');
    }
    if (photos.isEmpty) {
      throw AiTagsException('No photos to recognize');
    }

    final message = StringBuffer(
        'Suggest OpenStreetMap tags for the object in the attached photos.');
    final hint = explanation?.trim() ?? '';
    if (hint.isNotEmpty) {
      message.write('\nHint from the user: $hint');
    }

    final response = await _post(settings, {
      'model': settings.model,
      'messages': [
        {'role': 'system', 'content': kSystemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': message.toString()},
            for (final photo in photos)
              {
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:${photo.mimeType};base64,${base64Encode(photo.bytes)}',
                },
              },
          ],
        },
      ],
    });

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) {
      throw AiTagsException('Unexpected response from the AI model');
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AiTagsException('Unexpected response from the AI model');
    }
    final choice = choices.first;
    final choiceMessage = choice is Map ? choice['message'] : null;
    final content = choiceMessage is Map ? choiceMessage['content'] : null;
    if (content is! String) {
      throw AiTagsException('Unexpected response from the AI model');
    }

    final tags = parseAiTags(content);
    if (tags.isEmpty) {
      throw AiTagsException('The AI model could not recognize any tags',
          empty: true);
    }
    return tags;
  }

  Future<http.Response> _post(
      AiSettings settings, Map<String, dynamic> body) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(kEndpoint),
            headers: {
              'Authorization': 'Bearer ${settings.apiKey}',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://every-door.app',
              'X-Title': 'Every Door',
            },
            body: jsonEncode(body),
          )
          .timeout(kTimeout);
    } on Exception catch (e) {
      _logger.warning('OpenRouter request failed', e);
      throw AiTagsException('$e');
    }

    if (response.statusCode != 200) {
      _logger.warning('OpenRouter replied with ${response.statusCode}');
      throw AiTagsException(_extractError(response));
    }
    return response;
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        final error = data['error'];
        if (error is Map && error['message'] is String)
          return error['message'] as String;
        if (error is String) return error;
      }
    } on FormatException {
      // Not JSON, fall through to the HTTP code.
    }
    return 'HTTP ${response.statusCode}';
  }
}

/// Extracts OSM tags from a (possibly markdown-wrapped) JSON answer
/// from an AI model. Returns an empty map when no tags were found.
Map<String, String> parseAiTags(String content) {
  var text = content.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return {};

  Object? data;
  try {
    data = jsonDecode(text.substring(start, end + 1));
  } on FormatException {
    return {};
  }
  if (data is! Map) return {};

  final tags = <String, String>{};
  data.forEach((key, value) {
    if (key is! String || key.isEmpty) return;
    if (key.contains(' ') || key.contains('=')) return;
    String? strValue;
    if (value is String) {
      strValue = value.trim();
    } else if (value is num || value is bool) {
      strValue = value.toString();
    }
    if (strValue == null || strValue.isEmpty) return;
    tags[key] = strValue;
  });
  return tags;
}
