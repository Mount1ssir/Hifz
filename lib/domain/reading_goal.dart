class ReadingGoal {
  const ReadingGoal(
    this.id,
    this.name,
    this.pages,
    this.anchors,
    this.quota,
    this.interval,
    this.startDay,
    this.read, [
    this.recorded,
  ]);
  final int id, quota, interval, startDay, read;
  final Set<int>? recorded;
  Iterable<int> get unread => recorded == null
      ? anchors.skip(read)
      : anchors.where((id) => !recorded!.contains(id));
  bool get flexible => quota == 0;
  final String name;
  final bool pages;
  // One next-ayah anchor per selected page or verse, in reading order.
  final List<int> anchors;
  int get remaining => anchors.length - read;
  String get unit => pages ? 'صفحة' : 'آية';
  static int day(DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(1970)).inDays;
  int due(int today) {
    if (flexible || today < startDay) return 0;
    final scheduled = (1 + (today - startDay) ~/ interval) * quota;
    return (scheduled - read).clamp(0, remaining);
  }

  int get sessions => flexible ? 0 : (anchors.length + quota - 1) ~/ quota;
}
