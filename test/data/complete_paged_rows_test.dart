import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/data/complete_paged_rows.dart';

void main() {
  test('fetches every row when exports exceed the 500-row page size', () async {
    final ranges = <(int, int)>[];
    final rows = await fetchCompletePagedRows<int>(
      countRows: () async => 1001,
      pageSize: 500,
      ensureValid: () {},
      fetchPage: (from, to) async {
        ranges.add((from, to));
        return List.generate(to - from + 1, (index) => from + index);
      },
    );

    expect(rows, hasLength(1001));
    expect(rows.first, 0);
    expect(rows.last, 1000);
    expect(ranges, [(0, 499), (500, 999), (1000, 1000)]);
  });

  test('fetches all rows across multiple pages in order', () async {
    final ranges = <(int, int)>[];
    final rows = await fetchCompletePagedRows<int>(
      countRows: () async => 5,
      pageSize: 2,
      ensureValid: () {},
      fetchPage: (from, to) async {
        ranges.add((from, to));
        return List.generate(to - from + 1, (index) => from + index);
      },
    );

    expect(rows, [0, 1, 2, 3, 4]);
    expect(ranges, [(0, 1), (2, 3), (4, 4)]);
  });

  test('rejects short pages instead of returning an incomplete result', () {
    expect(
      () => fetchCompletePagedRows<int>(
        countRows: () async => 3,
        pageSize: 2,
        ensureValid: () {},
        fetchPage: (from, to) async => [from],
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('propagates a later page error instead of returning earlier rows', () {
    expect(
      () => fetchCompletePagedRows<int>(
        countRows: () async => 3,
        pageSize: 2,
        ensureValid: () {},
        fetchPage: (from, to) async {
          if (from > 0) {
            throw StateError('Page request failed.');
          }
          return [0, 1];
        },
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Page request failed.',
        ),
      ),
    );
  });

  test('aborts when account validation fails between pages', () {
    var validations = 0;
    expect(
      () => fetchCompletePagedRows<int>(
        countRows: () async => 3,
        pageSize: 2,
        ensureValid: () {
          validations++;
          if (validations == 4) {
            throw StateError('Account changed.');
          }
        },
        fetchPage: (from, to) async =>
            List.generate(to - from + 1, (index) => from + index),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
