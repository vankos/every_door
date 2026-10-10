// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'dart:typed_data';

import 'package:every_door/constants.dart';
import 'package:every_door/helpers/tags/main_key.dart';
import 'package:every_door/models/preset.dart';
import 'package:every_door/providers/ai_tags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;

/// A page for mapping an object from a photo: the photo (with an optional
/// comment) is sent to an AI model, and the tags it returns are used
/// to create a new point. Returns a [Preset] with those tags on success.
class PhotoMapPage extends ConsumerStatefulWidget {
  final Uint8List image;
  final String mimeType;

  const PhotoMapPage({
    required this.image,
    required this.mimeType,
  });

  @override
  ConsumerState createState() => _PhotoMapPageState();
}

class _PhotoMapPageState extends ConsumerState<PhotoMapPage> {
  final controller = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> recognizeTags() async {
    final loc = AppLocalizations.of(context)!;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final tags = await ref.read(aiTagsProvider).recognizeTags(
            image: widget.image,
            mimeType: widget.mimeType,
            explanation: controller.text,
          );
      // The preset type is NSI so that the editor detects the actual preset
      // (and its field list) by the returned tags, keeping all of them.
      final preset = Preset(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        name: _presetName(tags),
        addTags: tags,
        type: PresetType.nsi,
      );
      if (mounted) Navigator.pop(context, preset);
    } on AiTagsException catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.empty ? loc.photoMapNoTags : loc.photoMapError(e.message);
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = loc.photoMapError(e.toString());
        });
      }
    }
  }

  String _presetName(Map<String, String> tags) {
    final key = getMainKey(tags);
    final value = key != null ? tags[key] : null;
    if (value == null || value.isEmpty) return 'AI';
    return value
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.photoMapTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.memory(
                    widget.image,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: TextField(
                controller: controller,
                enabled: !loading,
                maxLines: 3,
                minLines: 1,
                style: kFieldTextStyle,
                decoration: InputDecoration(
                  labelText: loc.photoMapDescriptionLabel,
                  hintText: loc.photoMapDescriptionHint,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 0),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : recognizeTags,
                  icon: loading
                      ? const SizedBox(
                          width: 18.0,
                          height: 18.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                      loading ? loc.photoMapRecognizing : loc.photoMapSubmit),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
