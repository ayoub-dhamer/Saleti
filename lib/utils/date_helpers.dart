/// FIXED (polish #7): `someDate.add(Duration(days: n))` /
/// `.subtract(Duration(days: n))` add or remove exactly n*24 hours of
/// elapsed time — not "n calendar days". Across a daylight-saving
/// transition this can shift the resulting wall-clock hour/minute by ±1
/// (Dart's own documentation gives this exact example), and in the rarer
/// case that shift crosses midnight, even the calendar *date* can come out
/// wrong. That mattered in several places in this app: a Friday reminder
/// or the daily azan rescheduler landing an hour off its configured time
/// on the two nights a year it matters, or a lookahead/previous-day prayer
/// calculation silently using the wrong calendar date.
///
/// [addDays] targets an exact wall-clock time on an exact calendar day
/// instead, via the multi-argument `DateTime()` constructor — which
/// normalizes day/month overflow itself (`DateTime(2026, 3, 32)` already
/// correctly becomes April 1st) and is immune to DST drift, since it's not
/// duration arithmetic at all. Use `addDays(date, -n)` to go backward.
DateTime addDays(DateTime date, int days) {
  return DateTime(
    date.year,
    date.month,
    date.day + days,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}
