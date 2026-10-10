// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/providers/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';

final aiSettingsProvider =
    NotifierProvider<AiSettingsProvider, AiSettings>(AiSettingsProvider.new);

/// A vision model suggested for photo mapping: an OpenRouter model id
/// and a short name to show in the settings.
class AiModelOption {
  final String id;
  final String name;

  const AiModelOption(this.id, this.name);
}

/// Models with image input suggested on the AI settings page.
const kAiModels = <AiModelOption>[
  AiModelOption('google/gemini-3.7-flash', 'Gemini 3.7 Flash'),
  AiModelOption('openai/gpt-6-luna', 'GPT-6 Luna'),
  AiModelOption('qwen/qwen3.8-flash', 'Qwen3.8 Flash'),
  AiModelOption('~deepseek/deepseek-flash-latest', 'DeepSeek Flash Latest'),
];

/// Settings for the photo-to-tags mapping: the OpenRouter API key
/// and the name of a vision model.
class AiSettings {
  /// A vision model that is available on OpenRouter by default.
  static const kDefaultModel = 'google/gemini-3.7-flash';

  final String apiKey;
  final String model;

  const AiSettings({this.apiKey = '', this.model = kDefaultModel});

  bool get isConfigured => apiKey.isNotEmpty && model.isNotEmpty;

  AiSettings copyWith({String? apiKey, String? model}) => AiSettings(
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
      );
}

class AiSettingsProvider extends Notifier<AiSettings> {
  static final _logger = Logger('AiSettings');
  static const _kApiKey = 'openrouter_api_key';
  static const _kModel = 'openrouter_model';
  static const _secure = FlutterSecureStorage();

  Future<void>? _apiKeyLoad;

  @override
  AiSettings build() {
    // The API key is a secret, it is stored in the secure storage,
    // which can only be read asynchronously.
    _apiKeyLoad = _loadApiKey();
    final prefs = ref.read(sharedPrefsProvider).requireValue;
    return AiSettings(
      model: prefs.getString(_kModel) ?? AiSettings.kDefaultModel,
    );
  }

  /// Waits until the API key is read from the secure storage.
  Future<void> ensureApiKeyLoaded() => _apiKeyLoad ?? Future.value();

  Future<void> _loadApiKey() async {
    try {
      final key = await _secure.read(key: _kApiKey);
      if (key != null && key != state.apiKey) {
        state = state.copyWith(apiKey: key);
      }
    } on PlatformException catch (e) {
      _logger.warning('Failed to read OpenRouter API key', e);
    }
  }

  Future<void> saveApiKey(String value) async {
    value = value.trim();
    state = state.copyWith(apiKey: value);
    try {
      if (value.isEmpty) {
        await _secure.delete(key: _kApiKey);
      } else {
        await _secure.write(key: _kApiKey, value: value);
      }
    } on PlatformException catch (e) {
      _logger.warning('Failed to save OpenRouter API key', e);
    }
  }

  Future<void> saveModel(String value) async {
    value = value.trim();
    state = state.copyWith(
        model: value.isEmpty ? AiSettings.kDefaultModel : value);
    final prefs = ref.read(sharedPrefsProvider).requireValue;
    await prefs.setString(_kModel, state.model);
  }
}
