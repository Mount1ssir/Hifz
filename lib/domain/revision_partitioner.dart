import 'hifz_planner.dart';
import 'range_set.dart';

class RevisionPartitioner {
  /// Cuts after reaching each cumulative target, keeping each ayah whole.
  /// Empty portions are explicit when days exceed the available work.
  List<PlannedPortion> partition(
    RangeSet memorized, {
    required int days,
    required Map<int, int> weights,
  }) {
    RangeError.checkValueInInterval(days, 1, 0x7fffffff, 'days');
    final ids = memorized.ids.toList();
    final values = <int>[];
    for (final id in ids) {
      final weight = weights[id];
      if (weight == null || weight <= 0) {
        throw ArgumentError(
          'A positive revision weight is required for ayah $id.',
        );
      }
      values.add(weight);
    }
    final total = values.fold(0, (sum, weight) => sum + weight);
    var cursor = 0;
    var cumulative = 0;
    final portions = <PlannedPortion>[];
    for (var day = 1; day <= days; day++) {
      final ranges = <AyahRange>[];
      var portionWeight = 0;
      // Integer comparison avoids rounding errors at partition boundaries.
      while (cursor < ids.length && cumulative * days < day * total) {
        ranges.add(AyahRange(ids[cursor], ids[cursor]));
        portionWeight += values[cursor];
        cumulative += values[cursor];
        cursor++;
      }
      portions.add(PlannedPortion(RangeSet(ranges), portionWeight));
    }
    return List.unmodifiable(portions);
  }
}
