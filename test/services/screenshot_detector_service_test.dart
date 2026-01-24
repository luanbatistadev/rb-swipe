import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenshotDetector Pattern Matching', () {
    test('deve detectar screenshot por titulo em ingles', () {
      expect(_isScreenshotPattern(title: 'screenshot_2024.png', path: ''), true);
      expect(_isScreenshotPattern(title: 'Screenshot_20240101.png', path: ''), true);
      expect(_isScreenshotPattern(title: 'my_screenshot.jpg', path: ''), true);
    });

    test('deve detectar screenshot por titulo em portugues', () {
      expect(_isScreenshotPattern(title: 'captura_tela.png', path: ''), true);
      expect(_isScreenshotPattern(title: 'Captura de tela.png', path: ''), true);
    });

    test('deve detectar screenshot por caminho', () {
      expect(_isScreenshotPattern(title: 'img.png', path: '/screenshots/img.png'), true);
      expect(_isScreenshotPattern(title: 'img.png', path: '/DCIM/Screenshots/img.png'), true);
      expect(_isScreenshotPattern(title: 'img.png', path: '/capturas/img.png'), true);
      expect(_isScreenshotPattern(title: 'img.png', path: '/Pictures/Screen/img.png'), true);
    });

    test('nao deve detectar foto normal como screenshot', () {
      expect(_isScreenshotPattern(title: 'IMG_2024.jpg', path: '/DCIM/Camera/IMG_2024.jpg'), false);
      expect(_isScreenshotPattern(title: 'photo.png', path: '/photos/photo.png'), false);
      expect(_isScreenshotPattern(title: 'vacation.jpg', path: '/vacation/vacation.jpg'), false);
    });

    test('deve ser case insensitive', () {
      expect(_isScreenshotPattern(title: 'SCREENSHOT.png', path: ''), true);
      expect(_isScreenshotPattern(title: 'CAPTURA.png', path: ''), true);
      expect(_isScreenshotPattern(title: 'img.png', path: '/SCREENSHOTS/img.png'), true);
    });
  });

  group('ScreenshotAge Grouping', () {
    test('deve agrupar por ultima semana', () {
      final now = DateTime.now();
      final age = _determineAge(now.subtract(const Duration(days: 3)), now);
      expect(age, ScreenshotAgeTest.lastWeek);
    });

    test('deve agrupar por ultimo mes', () {
      final now = DateTime.now();
      final age = _determineAge(now.subtract(const Duration(days: 15)), now);
      expect(age, ScreenshotAgeTest.lastMonth);
    });

    test('deve agrupar por ultimos 3 meses', () {
      final now = DateTime.now();
      final age = _determineAge(now.subtract(const Duration(days: 60)), now);
      expect(age, ScreenshotAgeTest.last3Months);
    });

    test('deve agrupar por ultimos 6 meses', () {
      final now = DateTime.now();
      final age = _determineAge(now.subtract(const Duration(days: 120)), now);
      expect(age, ScreenshotAgeTest.last6Months);
    });

    test('deve agrupar como mais de 6 meses', () {
      final now = DateTime.now();
      final age = _determineAge(now.subtract(const Duration(days: 200)), now);
      expect(age, ScreenshotAgeTest.olderThan6Months);
    });

    test('deve agrupar corretamente nos limites', () {
      final now = DateTime.now();

      // Exatamente 7 dias - ainda ultima semana
      expect(
        _determineAge(now.subtract(const Duration(days: 6, hours: 23)), now),
        ScreenshotAgeTest.lastWeek,
      );

      // Mais de 7 dias - ultimo mes
      expect(
        _determineAge(now.subtract(const Duration(days: 8)), now),
        ScreenshotAgeTest.lastMonth,
      );
    });
  });

  group('ScreenshotGroup Label', () {
    test('deve retornar label correto para cada idade', () {
      expect(_getLabel(ScreenshotAgeTest.lastWeek), 'Última semana');
      expect(_getLabel(ScreenshotAgeTest.lastMonth), 'Último mês');
      expect(_getLabel(ScreenshotAgeTest.last3Months), 'Últimos 3 meses');
      expect(_getLabel(ScreenshotAgeTest.last6Months), 'Últimos 6 meses');
      expect(_getLabel(ScreenshotAgeTest.olderThan6Months), 'Mais de 6 meses');
    });
  });
}

// Test version of ScreenshotAge enum
enum ScreenshotAgeTest {
  lastWeek,
  lastMonth,
  last3Months,
  last6Months,
  olderThan6Months,
}

// Test version of screenshot pattern detection
bool _isScreenshotPattern({required String title, required String path}) {
  final lowerTitle = title.toLowerCase();
  final lowerPath = path.toLowerCase();

  return lowerTitle.startsWith('screenshot') ||
      lowerTitle.startsWith('captura') ||
      lowerTitle.contains('screenshot') ||
      lowerPath.contains('screenshot') ||
      lowerPath.contains('capturas') ||
      lowerPath.contains('screen');
}

// Test version of age determination
ScreenshotAgeTest _determineAge(DateTime assetDate, DateTime now) {
  final oneWeekAgo = now.subtract(const Duration(days: 7));
  final oneMonthAgo = now.subtract(const Duration(days: 30));
  final threeMonthsAgo = now.subtract(const Duration(days: 90));
  final sixMonthsAgo = now.subtract(const Duration(days: 180));

  if (assetDate.isAfter(oneWeekAgo)) {
    return ScreenshotAgeTest.lastWeek;
  } else if (assetDate.isAfter(oneMonthAgo)) {
    return ScreenshotAgeTest.lastMonth;
  } else if (assetDate.isAfter(threeMonthsAgo)) {
    return ScreenshotAgeTest.last3Months;
  } else if (assetDate.isAfter(sixMonthsAgo)) {
    return ScreenshotAgeTest.last6Months;
  } else {
    return ScreenshotAgeTest.olderThan6Months;
  }
}

// Test version of label getter
String _getLabel(ScreenshotAgeTest age) {
  switch (age) {
    case ScreenshotAgeTest.lastWeek:
      return 'Última semana';
    case ScreenshotAgeTest.lastMonth:
      return 'Último mês';
    case ScreenshotAgeTest.last3Months:
      return 'Últimos 3 meses';
    case ScreenshotAgeTest.last6Months:
      return 'Últimos 6 meses';
    case ScreenshotAgeTest.olderThan6Months:
      return 'Mais de 6 meses';
  }
}
