import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DuplicateDetector Hash Functions', () {
    test('averageHash deve retornar mesmo hash para dados identicos', () {
      final data1 = Uint8List.fromList([100, 150, 200, 50, 100, 150, 200, 50]);
      final data2 = Uint8List.fromList([100, 150, 200, 50, 100, 150, 200, 50]);

      final hash1 = _averageHash(data1);
      final hash2 = _averageHash(data2);

      expect(hash1, hash2);
    });

    test('averageHash deve retornar hashes diferentes para dados diferentes', () {
      final data1 = Uint8List.fromList([0, 0, 0, 0, 255, 255, 255, 255]);
      final data2 = Uint8List.fromList([255, 255, 255, 255, 0, 0, 0, 0]);

      final hash1 = _averageHash(data1);
      final hash2 = _averageHash(data2);

      expect(hash1, isNot(hash2));
    });

    test('averageHash deve retornar hashes similares para dados similares', () {
      final data1 = Uint8List.fromList([100, 150, 200, 50, 100, 150, 200, 50]);
      final data2 = Uint8List.fromList([102, 148, 198, 52, 100, 150, 200, 50]);

      final hash1 = _averageHash(data1);
      final hash2 = _averageHash(data2);
      final distance = _hammingDistance(hash1, hash2);

      expect(distance, lessThanOrEqualTo(2));
    });

    test('hammingDistance deve retornar 0 para hashes identicos', () {
      expect(_hammingDistance(0, 0), 0);
      expect(_hammingDistance(255, 255), 0);
      expect(_hammingDistance(123456, 123456), 0);
    });

    test('hammingDistance deve contar bits diferentes corretamente', () {
      expect(_hammingDistance(0, 1), 1);
      expect(_hammingDistance(0, 3), 2);
      expect(_hammingDistance(0, 7), 3);
      expect(_hammingDistance(0, 15), 4);
    });

    test('hammingDistance deve ser simetrico', () {
      expect(_hammingDistance(100, 200), _hammingDistance(200, 100));
      expect(_hammingDistance(0, 255), _hammingDistance(255, 0));
    });

    test('groupByHashSimilarity deve agrupar hashes similares', () {
      final hashes = {
        'a': 0,
        'b': 1,
        'c': 0xFFFF0000,
        'd': 0xFFFF0001,
      };

      final groups = _groupByHashSimilarity(hashes, threshold: 5);

      expect(groups.length, 2);
      expect(groups.any((g) => g.contains('a') && g.contains('b')), true);
      expect(groups.any((g) => g.contains('c') && g.contains('d')), true);
    });

    test('groupByHashSimilarity deve manter itens isolados quando muito diferentes', () {
      final hashes = {
        'a': 0,
        'b': 0xFFFFFFFF,
      };

      final groups = _groupByHashSimilarity(hashes, threshold: 5);

      expect(groups.length, 2);
    });
  });
}

int _averageHash(Uint8List imageData) {
  var sum = 0;
  for (var i = 0; i < imageData.length; i++) {
    sum += imageData[i];
  }
  final avg = sum ~/ imageData.length;

  var hash = 0;
  for (var i = 0; i < imageData.length && i < 64; i++) {
    if (imageData[i] > avg) {
      hash |= (1 << i);
    }
  }
  return hash;
}

int _hammingDistance(int a, int b) {
  var xor = a ^ b;
  var count = 0;
  while (xor != 0) {
    count += xor & 1;
    xor >>= 1;
  }
  return count;
}

List<List<String>> _groupByHashSimilarity(Map<String, int> hashes, {int threshold = 5}) {
  final keys = hashes.keys.toList();
  final visited = <String>{};
  final groups = <List<String>>[];

  for (final key in keys) {
    if (visited.contains(key)) continue;

    final group = <String>[key];
    visited.add(key);

    for (final other in keys) {
      if (visited.contains(other)) continue;

      final distance = _hammingDistance(hashes[key]!, hashes[other]!);
      if (distance <= threshold) {
        group.add(other);
        visited.add(other);
      }
    }

    groups.add(group);
  }

  return groups;
}
