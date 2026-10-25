// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/constants.dart';
import 'package:every_door/providers/ai_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;

/// Fields for choosing a photo recognition model: a dropdown with the
/// suggested vision models and a text field for any other OpenRouter
/// model id. The choice is saved immediately.
class AiModelPicker extends ConsumerStatefulWidget {
  final EdgeInsets padding;
  final bool enabled;

  const AiModelPicker({
    this.padding = const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
    this.enabled = true,
    super.key,
  });

  @override
  ConsumerState<AiModelPicker> createState() => _AiModelPickerState();
}

class _AiModelPickerState extends ConsumerState<AiModelPicker> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(aiSettingsProvider).model);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _chooseModel(String value) {
    _controller.text = value;
    ref.read(aiSettingsProvider.notifier).saveModel(value);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final model = ref.watch(aiSettingsProvider).model;
    return Column(
      children: [
        Padding(
          padding: widget.padding,
          child: DropdownButtonFormField<String>(
            // The key makes the field show the actual model, including
            // when it was typed into the field below or changed elsewhere.
            key: ValueKey(model),
            initialValue:
                kAiModels.any((option) => option.id == model) ? model : null,
            isExpanded: true,
            itemHeight: 64.0,
            decoration: InputDecoration(
              label: Text(loc.aiModelLabel),
              prefixIcon: const Icon(Icons.smart_toy),
            ),
            hint: Text(loc.aiModelChoose),
            // The button shows only the name: there is no room for the id
            // in a one-line dropdown field, unlike in the opened menu.
            selectedItemBuilder: (context) => [
              for (final option in kAiModels)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(option.name, overflow: TextOverflow.ellipsis),
                ),
            ],
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
            onChanged: widget.enabled
                ? (value) {
                    if (value == null) return;
                    _chooseModel(value);
                  }
                : null,
          ),
        ),
        Padding(
          padding: widget.padding,
          child: TextFormField(
            controller: _controller,
            enabled: widget.enabled,
            style: kFieldTextStyle,
            decoration: InputDecoration(
              label: Text(loc.aiModelCustomLabel),
              hintText: loc.aiModelHint,
              prefixIcon: const Icon(Icons.edit),
            ),
            onChanged: (value) {
              ref.read(aiSettingsProvider.notifier).saveModel(value);
            },
          ),
        ),
      ],
    );
  }
}
