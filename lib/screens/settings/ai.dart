// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/constants.dart';
import 'package:every_door/providers/ai_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  late final TextEditingController _keyController;
  late final TextEditingController _modelController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _keyController = TextEditingController(text: settings.apiKey);
    _modelController = TextEditingController(text: settings.model);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final model = ref.watch(aiSettingsProvider).model;
    // The API key is loaded from the secure storage asynchronously,
    // fill the field when it arrives.
    ref.listen(aiSettingsProvider, (previous, next) {
      if (next.apiKey.isNotEmpty && _keyController.text.isEmpty) {
        _keyController.text = next.apiKey;
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(loc.settingsAi)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
            child: TextFormField(
              controller: _keyController,
              style: kFieldTextStyle,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                label: Text(loc.aiApiKeyLabel),
                hintText: loc.aiApiKeyHint,
                prefixIcon: Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscureKey = !_obscureKey;
                    });
                  },
                ),
              ),
              onChanged: (value) {
                ref.read(aiSettingsProvider.notifier).saveApiKey(value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
            child: DropdownButtonFormField<String>(
              initialValue:
                  kAiModels.any((option) => option.id == model) ? model : null,
              isExpanded: true,
              itemHeight: 64.0,
              decoration: InputDecoration(
                label: Text(loc.aiModelLabel),
                prefixIcon: Icon(Icons.smart_toy),
              ),
              hint: Text(loc.aiModelChoose),
              items: [
                for (final option in kAiModels)
                  DropdownMenuItem(
                    value: option.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(option.name),
                        Text(
                          option.id,
                          style: TextStyle(
                              fontSize: 12.0, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                _modelController.text = value;
                ref.read(aiSettingsProvider.notifier).saveModel(value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
            child: TextFormField(
              controller: _modelController,
              style: kFieldTextStyle,
              decoration: InputDecoration(
                label: Text(loc.aiModelCustomLabel),
                hintText: loc.aiModelHint,
                prefixIcon: Icon(Icons.edit),
              ),
              onChanged: (value) {
                ref.read(aiSettingsProvider.notifier).saveModel(value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              loc.aiPrivacyNote,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13.0),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.done),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}
