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

/// A form field of a preset that the AI model can fill from photos.
class AiField {
  /// OSM tag key the field is stored under.
  final String key;

  /// Human-readable field label.
  final String label;

  /// Format hint or example value, if the field has one.
  final String? hint;

  /// Suggested values for fields with a limited set of options.
  final List<String>? values;

  /// Whether only the values from [values] are allowed (a radio button
  /// or a combo without custom values), as opposed to suggestions.
  final bool closedValues;

  /// Tag keys to use instead of [key] for fields that span several tags,
  /// for example payment methods or diets. Each key is set to "yes" or "no".
  final List<String>? outputKeys;

  const AiField({
    required this.key,
    required this.label,
    this.hint,
    this.values,
    this.closedValues = false,
    this.outputKeys,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        if (hint != null && hint!.isNotEmpty) 'hint': hint,
        if (values != null && values!.isNotEmpty) 'values': values,
        if (values != null && values!.isNotEmpty && closedValues)
          'closed': true,
        if (outputKeys != null && outputKeys!.isNotEmpty) 'keys': outputKeys,
      };
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
- When the language of the name is identifiable, add a language-specific tag
  "name:<language code>" as well, for example "name:ru", "name:en", "name:de".
  If the sign shows the name in several languages, add "name" plus one
  "name:<lang>" tag for each language.
- Add other tags (opening_hours, cuisine, brand, ...) only if you are sure about them.
- Do not invent details that are not visible. When in doubt, omit the tag.
- If the user hint is present, it has priority when the photos are ambiguous.
- If you cannot identify any object, return {}.
''';

  static const kFillFieldsPrompt = '''
You are an OpenStreetMap mapping assistant. The object on the photos has
already been identified, its type tags are known, and the user needs values
for the form fields of this object type.
Return a single JSON object with the values for the listed fields.

Rules:
- Reply with a single JSON object only, without markdown fences or explanations.
- Keys must be exactly the tag keys from the field list, or one of the keys
  from a field's "keys" list. Values must be strings.
- A field with a "keys" list spans several tags: reply with those tag keys
  instead of the field's own "key". Set each key to "yes" when the feature
  is present, or to "no" when it is explicitly absent. Omit unknown keys.
- Omit a field when you cannot determine its value with confidence from the
  photos, the known tags, or the user hint. Do not invent details.
- If a field has a "values" list, prefer one of those values. When the field
  also has "closed": true, reply with one of those values verbatim; otherwise
  another standard OSM value is allowed when none of them fits.
- When a field can have several values, join them with ";" in a single string.
- The opening_hours value must use the OSM opening_hours syntax, for example
  "Mo-Fr 08:00-18:00". The field "opening_hours" is one string, not an object.
- Phone numbers must be in the international format, starting with "+".
- Websites must be full URLs, for example "https://example.com".
- Do not repeat the tags that define the object type.
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
            ..._photoContent(photos),
          ],
        },
      ],
    });

    final tags = parseAiTags(_extractContent(response));
    if (tags.isEmpty) {
      throw AiTagsException('The AI model could not recognize any tags',
          empty: true);
    }
    return tags;
  }

  /// Sends the photos again, this time with the fields of the preset
  /// detected for the object, and returns the values the AI model
  /// suggested for those fields.
  Future<Map<String, String>> fillFields({
    required List<AiPhoto> photos,
    required Map<String, String> tags,
    required List<AiField> fields,
    String? explanation,
  }) async {
    final settings = _ref.read(aiSettingsProvider);
    if (!settings.isConfigured) {
      throw AiTagsException('OpenRouter API key or model is not set');
    }
    if (photos.isEmpty) {
      throw AiTagsException('No photos to fill fields from');
    }
    if (fields.isEmpty) return const {};

    final message = StringBuffer(
        'Fill in the fields for the object in the attached photos.');
    final hint = explanation?.trim() ?? '';
    if (hint.isNotEmpty) {
      message.write('\nHint from the user: $hint');
    }
    message.write('\nKnown tags: ${jsonEncode(tags)}');
    message.write(
        '\nFields to fill: ${jsonEncode(fields.map((f) => f.toJson()).toList())}');

    final response = await _post(settings, {
      'model': settings.model,
      'messages': [
        {'role': 'system', 'content': kFillFieldsPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': message.toString()},
            ..._photoContent(photos),
          ],
        },
      ],
    });

    final filled = parseAiTags(_extractContent(response));
    return filterFilledFields(filled, fields);
  }

  /// Builds the content list with the base64-encoded photos.
  List<Map<String, dynamic>> _photoContent(List<AiPhoto> photos) => [
        for (final photo in photos)
          {
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${photo.mimeType};base64,${base64Encode(photo.bytes)}',
            },
          },
      ];

  /// Reads the message content from an OpenRouter chat completion response.
  String _extractContent(http.Response response) {
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
    return content;
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

/// Keeps only the values the model was asked to fill. For fields that span
/// several tags (a "keys" list), accepts only "yes" and "no" values and
/// normalizes them to lower case.
Map<String, String> filterFilledFields(
    Map<String, String> filled, List<AiField> fields) {
  final allowed = <String>{};
  final multiKeys = <String>{};
  for (final field in fields) {
    final keys = field.outputKeys;
    if (keys != null && keys.isNotEmpty) {
      allowed.addAll(keys);
      multiKeys.addAll(keys);
    } else {
      allowed.add(field.key);
    }
  }

  final result = <String, String>{};
  filled.forEach((key, value) {
    if (!allowed.contains(key)) return;
    if (multiKeys.contains(key)) {
      final normalized = value.trim().toLowerCase();
      if (normalized != 'yes' && normalized != 'no') return;
      result[key] = normalized;
    } else {
      result[key] = value;
    }
  });
  return result;
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
