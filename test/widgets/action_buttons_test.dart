import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/widgets/action_buttons.dart';

void main() {
  group('ActionButtons', () {
    testWidgets('deve exibir botoes de apagar, voltar e manter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtons(
              onDelete: () {},
              onKeep: () {},
              onUndo: () {},
              canUndo: true,
            ),
          ),
        ),
      );

      expect(find.text('Apagar'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);
      expect(find.text('Manter'), findsOneWidget);
    });

    testWidgets('deve chamar onDelete ao tocar no botao apagar', (tester) async {
      var deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtons(
              onDelete: () => deleteCalled = true,
              onKeep: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();

      expect(deleteCalled, true);
    });

    testWidgets('deve chamar onKeep ao tocar no botao manter', (tester) async {
      var keepCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtons(
              onDelete: () {},
              onKeep: () => keepCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Manter'));
      await tester.pumpAndSettle();

      expect(keepCalled, true);
    });

    testWidgets('deve chamar onUndo ao tocar no botao voltar quando canUndo é true', (tester) async {
      var undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtons(
              onDelete: () {},
              onKeep: () {},
              onUndo: () => undoCalled = true,
              canUndo: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(undoCalled, true);
    });

    testWidgets('nao deve chamar onUndo quando canUndo é false', (tester) async {
      var undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtons(
              onDelete: () {},
              onKeep: () {},
              onUndo: () => undoCalled = true,
              canUndo: false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(undoCalled, false);
    });

    testWidgets('botao voltar deve ter opacidade reduzida quando desabilitado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtons(
              onDelete: () {},
              onKeep: () {},
              canUndo: false,
            ),
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(animatedOpacity.opacity, 0.3);
    });

    testWidgets('botao voltar deve ter opacidade total quando habilitado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtons(
              onDelete: () {},
              onKeep: () {},
              onUndo: () {},
              canUndo: true,
            ),
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(animatedOpacity.opacity, 1.0);
    });

    testWidgets('nao deve chamar callbacks quando isLoading é true', (tester) async {
      var deleteCalled = false;
      var keepCalled = false;
      var undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionButtons(
              onDelete: () => deleteCalled = true,
              onKeep: () => keepCalled = true,
              onUndo: () => undoCalled = true,
              canUndo: true,
              isLoading: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Apagar'));
      await tester.pump();
      expect(deleteCalled, false);

      await tester.tap(find.text('Manter'));
      await tester.pump();
      expect(keepCalled, false);

      await tester.tap(find.text('Voltar'));
      await tester.pump();
      expect(undoCalled, false);
    });
  });
}
