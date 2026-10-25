// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/generated/l10n/app_localizations.dart';
import 'package:every_door/providers/ai_settings.dart';
import 'package:every_door/widgets/ai_model_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAiSettings extends AiSettingsProvider {
  @override
  AiSettings build() => const AiSettings(
        apiKey: 'test-key',
        model: AiSettings.kDefaultModel,
      );

  @override
  Future<void> ensureApiKeyLoaded() async {}

  @override
  Future<void> saveModel(String value) async {
    value = value.trim();
    state =
        state.copyWith(model: value.isEmpty ? AiSettings.kDefaultModel : value);
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [aiSettingsProvider.overrideWith(_FakeAiSettings.new)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpPicker(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AiModelPicker()),
      ),
    ));
  }

  testWidgets('shows and saves a suggested model', (tester) async {
    await pumpPicker(tester);
    expect(find.text('Gemini 3.7 Flash'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qwen3.8 Flash').last);
    await tester.pumpAndSettle();

    expect(container.read(aiSettingsProvider).model, 'qwen/qwen3.8-flash');
    expect(find.text('Qwen3.8 Flash'), findsOneWidget);
  });

  testWidgets('saves a custom model id', (tester) async {
    await pumpPicker(tester);

    await tester.enterText(
        find.byType(TextFormField), 'anthropic/claude-4-opus');
    await tester.pumpAndSettle();

    expect(container.read(aiSettingsProvider).model, 'anthropic/claude-4-opus');
    expect(find.text('Выберите модель'), findsOneWidget);
  });
}
