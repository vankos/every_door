// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/fields/checkbox.dart';
import 'package:every_door/fields/combo.dart';
import 'package:every_door/fields/inline_combo.dart';
import 'package:every_door/fields/many_combo.dart';
import 'package:every_door/fields/payment.dart';
import 'package:every_door/fields/radio.dart';
import 'package:every_door/models/field.dart';
import 'package:every_door/providers/ai_tags.dart';

/// Field keys that edit several tags at once or are not OSM tag keys,
/// so they cannot be described as a single key.
const kPseudoFieldKeys = {'-', 'addr', 'address', 'payment'};

/// Payment tags the model may fill for the standard payment field.
/// All of them are known OSM values, and the editor understands the
/// generic keys plus the card options.
const kPaymentTagKeys = <String>[
  'payment:cash',
  'payment:cards',
  'payment:credit_cards',
  'payment:debit_cards',
  'payment:cheque',
  'payment:contactless',
  'payment:app',
  'payment:cryptocurrencies',
  'payment:visa',
  'payment:mastercard',
  'payment:maestro',
  'payment:american_express',
  'payment:unionpay',
  'payment:jcb',
  'payment:mir',
  'payment:apple_pay',
  'payment:google_pay',
  'payment:alipay',
  'payment:wechat',
  'payment:paypal',
];

/// Upper limit for option lists sent to the model: combo fields can have
/// thousands of taginfo values, and the prompt does not need all of them.
const kMaxAiFieldValues = 30;

final _tagKeyRe = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_:.-]*$');

/// Builds a list of fields for the AI model from the fields the editor
/// would show for the object. Skips fields that cannot be described by
/// tag keys, and duplicate fields.
List<AiField> buildAiFields(Iterable<PresetField> fields) {
  final result = <AiField>[];
  final seen = <String>{};
  for (final field in fields) {
    final aiField = describeAiField(field);
    if (aiField == null || !seen.add(aiField.key)) continue;
    result.add(aiField);
  }
  return result;
}

/// Converts an editor field to a field description for the AI model.
/// Returns null for fields that cannot be described by tag keys.
AiField? describeAiField(PresetField field) {
  final String key = field.key;

  // The standard payment field edits a set of payment:* tags,
  // so it is described as one field with several output keys.
  if (field is PaymentPresetField) {
    return AiField(
      key: key,
      label: field.label.isNotEmpty ? field.label : key,
      hint: 'accepted payment methods visible on the sign or stickers; '
          'set accepted keys to "yes", and set payment:cards to "no" '
          'when cards are not accepted',
      outputKeys: kPaymentTagKeys,
    );
  }

  if (kPseudoFieldKeys.contains(key) || !_tagKeyRe.hasMatch(key)) return null;
  // Multi-tag fields: the value is a set of keys, not a single tag value.
  if (field is ManyComboPresetField) return null;

  String? hint = field.placeholder;
  List<String>? values;
  bool closedValues = false;

  if (field is ComboPresetField) {
    if (field.type == ComboType.multi) {
      // The standard payment field already covers the payment:* tags.
      if (key == 'payment:') return null;
      final keys = _multiKeys(key, field.options);
      if (keys.isEmpty) return null;
      return AiField(
        key: key,
        label: field.label.isNotEmpty ? field.label : key,
        hint: hint ?? 'set to "yes" for the options the place has',
        outputKeys: keys,
      );
    }
    // Opening hours have their own syntax, and combo options are just
    // examples of values used in the area.
    if (!key.startsWith('opening_hours') && field.options.isNotEmpty) {
      values = _limitValues(field.options);
      closedValues = !field.customValues;
    }
  } else if (field is InlineComboPresetField) {
    if (field.options.isNotEmpty) {
      values = _limitValues(field.options);
      closedValues = !field.customValues;
    }
  } else if (field is RadioPresetField) {
    if (field.options.isNotEmpty) {
      values = _limitStrings(field.options);
      closedValues = true;
    }
  } else if (field is CheckboxPresetField) {
    final options = field.options;
    final yes =
        options != null && options.length == 2 ? options[1].value : 'yes';
    values = [yes, 'no'];
    closedValues = true;
    hint ??= 'yes or no';
  }

  hint ??= _fieldHint(key);
  return AiField(
    key: key,
    label: field.label.isNotEmpty ? field.label : key,
    hint: hint,
    values: values,
    closedValues: closedValues,
  );
}

/// Returns unique option values, capped to keep the prompt small.
List<String> _limitValues(Iterable<ComboOption> options) =>
    _limitStrings(options.map((option) => option.value));

/// Builds tag keys for a multi-value field: the field key is a prefix,
/// and each option value completes it, for example diet: + vegan.
List<String> _multiKeys(String prefix, Iterable<ComboOption> options) {
  final keys = <String>[];
  for (final option in options) {
    final key = '$prefix${option.value}';
    if (!keys.contains(key) && _tagKeyRe.hasMatch(key)) keys.add(key);
    if (keys.length >= kMaxAiFieldValues) break;
  }
  return keys;
}

List<String> _limitStrings(Iterable<String> options) {
  final values = <String>[];
  for (final value in options) {
    if (values.contains(value)) continue;
    values.add(value);
    if (values.length >= kMaxAiFieldValues) break;
  }
  return values;
}

String? _fieldHint(String key) {
  if (key.startsWith('opening_hours')) {
    return 'OSM opening_hours syntax, e.g. Mo-Fr 08:00-18:00';
  }
  if (key == 'phone' ||
      key == 'mobile' ||
      key == 'fax' ||
      key == 'contact:phone' ||
      key == 'contact:mobile' ||
      key == 'contact:fax') {
    return 'international phone number, e.g. +7 999 123-45-67';
  }
  if (key == 'email' || key == 'contact:email') return 'email address';
  if (key == 'website' ||
      key == 'contact:website' ||
      key == 'contact:facebook' ||
      key == 'contact:instagram' ||
      key == 'contact:vk' ||
      key == 'image' ||
      key == 'mapillary' ||
      key == 'panoramax') {
    return 'full URL';
  }
  if (key == 'wheelchair') return 'one of: yes, no, limited, designated';
  if (key == 'level') return 'floor level, e.g. 0, 1, -1';
  return null;
}
