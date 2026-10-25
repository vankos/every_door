// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/constants.dart';
import 'package:every_door/helpers/tags/main_key.dart';
import 'package:every_door/models/preset.dart';
import 'package:every_door/providers/ai_tags.dart';
import 'package:every_door/widgets/ai_model_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;

/// Asks where to take photos from and picks one or more of them.
/// Returns an empty list when the user cancelled or the photos could not
/// be taken or picked.
Future<List<AiPhoto>> pickPhotos(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_camera),
            title: Text(loc.photoMapTakePhoto),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text(loc.photoMapPickPhoto),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return const [];

  final picker = ImagePicker();
  List<XFile> files;
  try {
    if (source == ImageSource.camera) {
      final file = await picker.pickImage(
        source: source,
        maxWidth: 2000.0,
        imageQuality: 85,
      );
      files = file == null ? const <XFile>[] : [file];
    } else {
      // The system picker allows selecting several photos at once.
      files = await picker.pickMultiImage(
        maxWidth: 2000.0,
        imageQuality: 85,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.photoMapPhotoFailed(e.toString()))),
      );
    }
    return const [];
  }

  final photos = <AiPhoto>[];
  for (final file in files) {
    final bytes = await file.readAsBytes();
    photos.add(AiPhoto(bytes, imageMimeType(file)));
  }
  return photos;
}

/// Guesses the mime type of a picked photo.
String imageMimeType(XFile file) {
  final mime = file.mimeType;
  if (mime != null && mime.isNotEmpty) return mime;
  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

/// A page for mapping an object from photos: the photos (with an optional
/// comment) are sent to an AI model, and the tags it returns are used
/// to create a new point. Returns a [Preset] with those tags on success.
class PhotoMapPage extends ConsumerStatefulWidget {
  final List<AiPhoto> photos;

  const PhotoMapPage({
    required this.photos,
  });

  @override
  ConsumerState createState() => _PhotoMapPageState();
}

class _PhotoMapPageState extends ConsumerState<PhotoMapPage> {
  late final List<AiPhoto> photos = List.of(widget.photos);
  final controller = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> addPhoto() async {
    final picked = await pickPhotos(context);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      photos.addAll(picked);
    });
  }

  void removePhoto(int index) {
    setState(() {
      photos.removeAt(index);
    });
  }

  void showPhoto(AiPhoto photo) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(photo.bytes),
        ),
      ),
    );
  }

  Future<void> recognizeTags() async {
    final loc = AppLocalizations.of(context)!;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final tags = await ref.read(aiTagsProvider).recognizeTags(
            photos: photos,
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

  Widget _buildPhoto(AiPhoto photo, int index, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => showPhoto(photo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.memory(
                photo.bytes,
                width: 110.0,
                height: 110.0,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              top: 2.0,
              right: 2.0,
              child: Tooltip(
                message: loc.photoMapRemovePhoto,
                child: GestureDetector(
                  onTap: () => removePhoto(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4.0),
                    child: const Icon(Icons.close,
                        size: 16.0, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddPhoto(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: addPhoto,
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          width: 110.0,
          height: 110.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, color: Colors.grey.shade700),
              const SizedBox(height: 4.0),
              Text(
                loc.photoMapAddPhoto,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.0, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.photoMapTitle)),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 130.0,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10.0),
                children: [
                  for (int i = 0; i < photos.length; i++)
                    _buildPhoto(photos[i], i, loc),
                  if (!loading) _buildAddPhoto(loc),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
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
                  AiModelPicker(enabled: !loading),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 0),
                      child: Text(
                        error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.0),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(loading
                            ? loc.photoMapRecognizing
                            : loc.photoMapSubmit),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
