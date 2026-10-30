import 'dart:math' as math;

Future<List<T>> fetchCompletePagedRows<T>({
  required Future<int> Function() countRows,
  required Future<List<T>> Function(int from, int to) fetchPage,
  required int pageSize,
  required void Function() ensureValid,
}) async {
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Must be greater than 0.');
  }

  ensureValid();
  final totalCount = await countRows();
  ensureValid();
  if (totalCount < 0) {
    throw StateError('The export row count was invalid.');
  }

  final rows = <T>[];
  for (var offset = 0; offset < totalCount; offset += pageSize) {
    final end = math.min(offset + pageSize, totalCount);
    final page = await fetchPage(offset, end - 1);
    ensureValid();
    if (page.length != end - offset) {
      throw StateError(
        'Account data changed during export. Please try exporting again.',
      );
    }
    rows.addAll(page);
  }
  return rows;
}
