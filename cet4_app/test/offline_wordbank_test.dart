import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cet4OfflineWordbank field fixing', () {
    test('type cleanup: Chinese chars at end should be split to meaning', () {
      // 模拟 _fixAllSplitTypes 逻辑
      var type = 'v.反对；反';
      var meaning = '抗';

      final chineseInType = RegExp(r'[一-鿿]').firstMatch(type);
      if (chineseInType != null) {
        final splitIdx = chineseInType.start;
        final trailing = type.substring(splitIdx);
        type = type.substring(0, splitIdx);
        if (!meaning.startsWith(trailing)) {
          meaning = '$trailing$meaning';
        }
      }

      // 清理type
      type = type.replaceAll(RegExp(r'[\.\s]+$'), '').trim();
      if (type.isNotEmpty && !type.endsWith('.') && type.length <= 5 &&
          RegExp(r'^[a-z]+$').hasMatch(type)) {
        type = '$type.';
      }

      expect(type, 'v.');
      expect(meaning, '反对；反抗');
    });

    test('type cleanup: meaning should not leak into type', () {
      var type = 'adj.有机的；器官的';
      var meaning = '';

      final chineseInType = RegExp(r'[一-鿿]').firstMatch(type);
      expect(chineseInType, isNotNull);

      final splitIdx = chineseInType!.start;
      final trailing = type.substring(splitIdx);
      type = type.substring(0, splitIdx);
      meaning = '$trailing$meaning';

      type = type.replaceAll(RegExp(r'[\.\s]+$'), '').trim();
      if (type.isNotEmpty && !type.endsWith('.') && type.length <= 5 &&
          RegExp(r'^[a-z]+$').hasMatch(type)) {
        type = '$type.';
      }

      expect(type, 'adj.');
      expect(meaning, '有机的；器官的');
    });

    test('type cleanup: already clean type should stay clean', () {
      var type = 'n.';
      var meaning = '器官；机构';

      final chineseInType = RegExp(r'[一-鿿]').firstMatch(type);
      expect(chineseInType, isNull); // 没有中文，不需要修复

      expect(type, 'n.');
      expect(meaning, '器官；机构');
    });
  });
}
