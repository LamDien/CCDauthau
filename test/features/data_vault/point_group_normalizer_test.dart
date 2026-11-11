import 'package:cc_dau_thau/features/data_vault/domain/services/point_group_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointGroupNormalizer', () {
    test('returns null for null, empty, or whitespace-only values', () {
      expect(PointGroupNormalizer.normalizeKey(null), isNull);
      expect(PointGroupNormalizer.normalizeKey(''), isNull);
      expect(PointGroupNormalizer.normalizeKey('   \t\n\u00A0  '), isNull);
      expect(PointGroupNormalizer.normalizeDisplayLabel('   '), isNull);
    });

    test('normalizes casing and collapses irregular whitespace into one key', () {
      final first = PointGroupNormalizer.normalizeKey('Ưu đãi nhà thầu');
      final second = PointGroupNormalizer.normalizeKey(
        '  ưu\u00A0\u00A0đãi   NHÀ\tTHẦU  ',
      );

      expect(first, equals('ưu đãi nhà thầu'));
      expect(second, equals(first));
    });

    test('preserves readable casing for display label while trimming spaces', () {
      final label = PointGroupNormalizer.normalizeDisplayLabel(
        '  Hạn   mức\nchỉ định thầu  ',
      );
      expect(label, equals('Hạn mức chỉ định thầu'));
    });
  });
}

