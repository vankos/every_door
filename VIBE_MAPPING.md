# Vibe mapping: adding points from photos

This fork of [Every Door](https://github.com/Zverik/every_door) adds photo
mapping: take a photo of a place, and an AI model suggests OSM tags for it.

## How it works

1. Tap the "+" button to add a point: the type chooser screen opens.
2. Tap the camera icon in the top right corner of the type chooser.
3. Choose "Take a photo" or "Open an existing photo".
4. On the next screen you can add more photos with the "+" tile: for
   example, one photo of the signboard with the name and another one with
   the opening hours. Tap a photo to view it full screen; remove it with
   the cross in its corner.
5. Optionally describe what to map on the photos (for example,
   "this is a pharmacy").
6. Tap "Recognize tags": all photos and the comment are sent to the
   [OpenRouter](https://openrouter.ai/) API, and the vision model replies
   with OSM tags. The tags are put into a new point and the usual editor
   opens, with the field list detected from those tags.
7. Check and fix the tags as usual, then save the point.

## Configuration

Open "Settings" → "Photo mapping" → "OpenRouter API":

* **API key** — create one at https://openrouter.ai/keys.
  It is stored in the secure storage (Android Keystore, iOS keychain),
  not in plain preferences.
* **Image recognition model** — choose one of the suggested vision models
  (all of them support image input on OpenRouter):

  | Model | OpenRouter id |
  | --- | --- |
  | Gemini 3.7 Flash (default) | `google/gemini-3.7-flash` |
  | GPT-6 Luna | `openai/gpt-6-luna` |
  | Qwen3.8 Flash | `qwen/qwen3.8-flash` |
  | DeepSeek Flash Latest | `~deepseek/deepseek-flash-latest` |

  Any other model id can be entered in the text field below the list.

Without an API key the camera button suggests opening the settings.

## Releases

APKs are built on GitHub Actions (`.github/workflows/build-apk.yml`):

* **Manually**: Actions → "Build Android APK" → Run workflow,
  choose the flavor (`prod` by default). The APK is attached to the run
  as an artifact (kept for 60 days).
* **By tag**: push a tag like `v1.0` — the workflow builds the APK and
  publishes a GitHub release with the APK attached.

The APK is signed with a personal key (keystore secrets
`KEYSTORE_JKS` and `KEYSTORE_PASSWORD` in the repository). The same key
is used for local builds when `android/key.properties` and
`keystore/everydoor.jks` are present (both are gitignored).

Keep a backup of the keystore and its password: without them you cannot
update an installed app, only reinstall it (losing app data).

Note: the `prod` flavor has the same package id as the official Every
Door, but a different signature, so an installed official app has to be
removed first. The `beta` flavor (`info.zverev.ilya.every_door.beta`)
installs alongside it.

## Privacy

Photos and the comment are sent to OpenRouter and the model provider.
Suggested tags may be wrong: they are only a draft, review them before
uploading to OpenStreetMap.

## Implementation notes

* `lib/providers/ai_settings.dart` — OpenRouter settings (key + model list).
* `lib/providers/ai_tags.dart` — the OpenRouter chat completions client
  (base64 image + text) and the JSON-to-tags parser.
* `lib/screens/editor/photo_map.dart` — photo preview, comment field and
  the "Recognize tags" button. Returns a `Preset` with the AI tags.
* `lib/screens/editor/types.dart` — the camera button on the type chooser.
* `lib/screens/settings/ai.dart` — the settings page.
* `test/ai_tags_test.dart` — unit tests for the tags parser.

The returned tags are passed to the editor as a preset of type
`PresetType.nsi`, so the editor detects the actual preset by the tags and
loads its field list, while keeping all the AI-suggested tags.

## Local build notes (Windows)

This project needs a few extra steps when building locally:

* `assets/presets.db` is not in the repository (it is gitignored):
  download it from https://textual.ru/presets.db.
* `flutter gen-l10n` requires a stub `lib/l10n/app_zh.arb` (CI creates it):
  `echo '{}' > lib/l10n/app_zh.arb`.
* The Android app has `prod` and `beta` flavors, so the build command is
  `flutter build apk --flavor prod` (without the flavor Flutter complains
  it cannot find the apk).
* `dart run build_runner build` needs a Flutter SDK path without spaces
  (the `objective_c` native assets hook fails otherwise). If the SDK is in
  a path with spaces, create a junction and run Flutter through it:

  ```powershell
  New-Item -ItemType Junction -Path "C:\flutter" -Target "<path-to-flutter-sdk>"
  C:\flutter\bin\flutter.bat build apk --flavor prod
  ```
