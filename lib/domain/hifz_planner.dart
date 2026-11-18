import 'range_set.dart';
import 'riwayah.dart';

enum QuotaUnit { ayahs, lines, pages }

abstract interface class MemorizationOrder {
  List<int> arrange(RangeSet remaining);
}

class ForwardOrder implements MemorizationOrder {
  const ForwardOrder();

  @override
  List<int> arrange(RangeSet remaining) => remaining.ids.toList();
}

class BackwardOrder implements MemorizationOrder {
  const BackwardOrder();

  @override
  List<int> arrange(RangeSet remaining) =>
      remaining.ids.toList().reversed.toList();
}

class CustomOrder implements MemorizationOrder {
  CustomOrder(Iterable<AyahRange> ranges) : ranges = List.unmodifiable(ranges);
  final List<AyahRange> ranges;

  @override
  List<int> arrange(RangeSet remaining) {
    final pending = remaining.ids.toSet();
    final ordered = <int>[];
    for (final range in ranges) {
      for (var id = range.first; id <= range.last; id++) {
        if (pending.remove(id)) ordered.add(id);
      }
    }
    if (pending.isNotEmpty) {
      throw ArgumentError('Custom order must cover every remaining ayah.');
    }
    return ordered;
  }
}

class DailyQuota {
  DailyQuota._(this.target, this._lineWeights) {
    RangeError.checkValueInInterval(target, 1, 0x7fffffff, 'quota');
  }

  factory DailyQuota.ayahs(int count) => DailyQuota._(count, null);

  /// Weights must come from a verified mushaf layout.
  factory DailyQuota.lines(int count, Map<int, int> weights) =>
      DailyQuota._(count, Map.unmodifiable(weights));

  factory DailyQuota.pages(
    int count,
    Map<int, int> weights, {
    required int linesPerPage,
  }) {
    RangeError.checkValueInInterval(
      linesPerPage,
      1,
      0x7fffffff,
      'linesPerPage',
    );
    return DailyQuota.lines(count * linesPerPage, weights);
  }

  final int target;
  final Map<int, int>? _lineWeights;

  int weight(int id) {
    if (_lineWeights == null) return 1;
    final value = _lineWeights[id];
    if (value == null || value <= 0) {
      throw StateError('Verified line weight unavailable for ayah $id.');
    }
    return value;
  }
}

class PlannedPortion {
  const PlannedPortion(this.ayahs, this.weight);
  final RangeSet ayahs;
  final int weight;
}

class HifzPlanner {
  List<PlannedPortion> plan({
    required Riwayah riwayah,
    required RangeSet memorized,
    required DailyQuota quota,
    MemorizationOrder order = const ForwardOrder(),
  }) {
    final remaining = memorized.complement(riwayah.totalAyahs);
    final ordered = order.arrange(remaining);
    // Strategies must preserve coverage exactly, even when supplied by callers.
    final expected = remaining.ids.toSet();
    if (ordered.length != expected.length ||
        ordered.toSet().length != expected.length ||
        !expected.containsAll(ordered)) {
      throw ArgumentError(
        'Memorization order must contain each remaining ayah once.',
      );
    }
    final result = <PlannedPortion>[];
    var current = <AyahRange>[];
    var weight = 0;
    for (final id in ordered) {
      current.add(AyahRange(id, id));
      weight += quota.weight(id);
      if (weight >= quota.target) {
        result.add(PlannedPortion(RangeSet(current), weight));
        current = [];
        weight = 0;
      }
    }
    if (current.isNotEmpty) {
      result.add(PlannedPortion(RangeSet(current), weight));
    }
    return List.unmodifiable(result);
  }
}
