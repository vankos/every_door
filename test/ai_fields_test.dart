// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/fields/address.dart';
import 'package:every_door/fields/checkbox.dart';
import 'package:every_door/fields/combo.dart';
import 'package:every_door/fields/many_combo.dart';
import 'package:every_door/fields/payment.dart';
import 'package:every_door/fields/radio.dart';
import 'package:every_door/fields/section.dart';
import 'package:every_door/fields/text.dart';
import 'package:every_door/helpers/ai_fields.dart';
import 'package:every_door/providers/ai_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAiFields', () {
    test('converts plain fields and adds format hints', () {
      final fields = buildAiFields([
        const TextPresetField(key: 'name', label: 'Name'),
        const TextPresetField(key: 'phone', label: 'Phone'),
        const TextPresetField(key: 'opening_hours', label: 'Opening hours'),
      ]);

      expect(fields.map((f) => f.key), ['name', 'phone', 'opening_hours']);
      expect(fields[1].hint, contains('+'));
      expect(fields[2].hint, contains('Mo-Fr'));
    });

    test('passes the options of choice fields', () {
      final radio = buildAiFields([
        RadioPresetField(
          key: 'wheelchair',
          label: 'Wheelchair',
          options: ['yes', 'no', 'limited'],
        ),
      ]);
      expect(radio.single.values, ['yes', 'no', 'limited']);
      expect(radio.single.closedValues, isTrue);

      final combo = buildAiFields([
        ComboPresetField(
          key: 'cuisine',
          label: 'Cuisine',
          type: ComboType.semi,
          options: [ComboOption('pizza'), ComboOption('burger')],
        ),
      ]);
      expect(combo.single.values, ['pizza', 'burger']);
      expect(combo.single.closedValues, isFalse);

      final closedCombo = buildAiFields([
        ComboPresetField(
          key: 'internet_access',
          label: 'Internet access',
          type: ComboType.regular,
          customValues: false,
          options: [ComboOption('yes'), ComboOption('wlan')],
        ),
      ]);
      expect(closedCombo.single.closedValues, isTrue);
    });

    test('does not send opening_hours options as values', () {
      final fields = buildAiFields([
        ComboPresetField(
          key: 'opening_hours',
          label: 'Opening hours',
          type: ComboType.regular,
          options: [ComboOption('Mo-Fr 08:00-18:00')],
        ),
      ]);

      expect(fields.single.values, isNull);
      expect(fields.single.hint, contains('Mo-Fr'));
    });

    test('describes checkboxes as yes/no fields', () {
      final fields = buildAiFields([
        CheckboxPresetField(
          key: 'outdoor_seating',
          label: 'Outdoor seating',
          tristate: true,
        ),
      ]);
      expect(fields.single.values, ['yes', 'no']);
      expect(fields.single.hint, 'yes or no');
    });

    test('describes the payment field with payment:* keys', () {
      final fields = buildAiFields([
        PaymentPresetField(label: 'Accept cards'),
      ]);

      expect(fields.single.key, 'payment');
      expect(fields.single.outputKeys, contains('payment:cash'));
      expect(fields.single.outputKeys, contains('payment:cards'));
      expect(fields.single.outputKeys, contains('payment:contactless'));
      expect(fields.single.toJson()['keys'], isNotEmpty);
    });

    test('describes multi-value fields like diet', () {
      final fields = buildAiFields([
        ComboPresetField(
          key: 'diet:',
          label: 'Diet',
          type: ComboType.multi,
          options: [ComboOption('vegetarian'), ComboOption('vegan')],
        ),
      ]);

      expect(fields.single.outputKeys, ['diet:vegetarian', 'diet:vegan']);
      expect(fields.single.values, isNull);
    });

    test('skips payment:* multi fields covered by the payment field', () {
      final fields = buildAiFields([
        ComboPresetField(
          key: 'payment:',
          label: 'Payment methods',
          type: ComboType.multi,
          options: [ComboOption('cash')],
        ),
      ]);

      expect(fields, isEmpty);
    });

    test('skips fields without a single tag key', () {
      final fields = buildAiFields([
        SectionPresetField('Section'),
        AddressField(label: 'Address'),
        ManyComboPresetField(
          keys: ['diet:vegetarian', 'diet:vegan'],
          label: 'Diet',
          options: [ComboOption('vegetarian'), ComboOption('vegan')],
        ),
        const TextPresetField(key: 'name', label: 'Name'),
      ]);

      expect(fields.map((f) => f.key), ['name']);
    });

    test('keeps only the first field for a key', () {
      final fields = buildAiFields([
        const TextPresetField(key: 'name', label: 'Name'),
        const TextPresetField(key: 'name', label: 'Name again'),
        const TextPresetField(key: 'website', label: 'Website'),
      ]);

      expect(fields.map((f) => f.label), ['Name', 'Website']);
    });

    test('limits long option lists', () {
      final options = [
        for (int i = 0; i < kMaxAiFieldValues + 10; i++) ComboOption('v$i'),
      ];
      final fields = buildAiFields([
        ComboPresetField(
          key: 'cuisine',
          label: 'Cuisine',
          type: ComboType.semi,
          options: options,
        ),
      ]);

      expect(fields.single.values, hasLength(kMaxAiFieldValues));
      expect(fields.single.values!.first, 'v0');
    });
  });

  group('AiField', () {
    test('serializes only non-empty fields', () {
      expect(const AiField(key: 'name', label: 'Name').toJson(),
          {'key': 'name', 'label': 'Name'});
      expect(
        const AiField(
          key: 'wheelchair',
          label: 'Wheelchair',
          hint: 'yes or no',
          values: ['yes', 'no'],
        ).toJson(),
        {
          'key': 'wheelchair',
          'label': 'Wheelchair',
          'hint': 'yes or no',
          'values': ['yes', 'no'],
        },
      );
    });

    test('marks closed value lists', () {
      expect(
        const AiField(
          key: 'wheelchair',
          label: 'Wheelchair',
          values: ['yes', 'no'],
          closedValues: true,
        ).toJson()['closed'],
        isTrue,
      );
      expect(
        const AiField(
          key: 'cuisine',
          label: 'Cuisine',
          values: ['pizza'],
        ).toJson(),
        isNot(contains('closed')),
      );
    });

    test('serializes multi-key fields', () {
      expect(
        const AiField(
          key: 'payment',
          label: 'Payment',
          outputKeys: ['payment:cash', 'payment:cards'],
        ).toJson(),
        {
          'key': 'payment',
          'label': 'Payment',
          'keys': ['payment:cash', 'payment:cards'],
        },
      );
    });
  });

  group('filterFilledFields', () {
    const payment = AiField(
      key: 'payment',
      label: 'Payment',
      outputKeys: ['payment:cash', 'payment:cards'],
    );
    const diet = AiField(
      key: 'diet:',
      label: 'Diet',
      outputKeys: ['diet:vegetarian'],
    );

    test('keeps values of requested single-key fields', () {
      expect(
        filterFilledFields(
          {'name': 'Cafe', 'amenity': 'cafe'},
          [const AiField(key: 'name', label: 'Name')],
        ),
        {'name': 'Cafe'},
      );
    });

    test('accepts and normalizes multi-key values', () {
      expect(
        filterFilledFields(
          {
            'payment:cash': ' YES ',
            'payment:cards': 'maybe',
            'payment:visa': 'yes',
            'diet:vegetarian': 'Yes',
          },
          [payment, diet],
        ),
        {'payment:cash': 'yes', 'diet:vegetarian': 'yes'},
      );
    });

    test('does not accept the field key of a multi-key field', () {
      expect(filterFilledFields({'payment': 'yes'}, [payment]), isEmpty);
    });
  });
}
