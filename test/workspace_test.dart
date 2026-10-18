import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contact_card_builder/main.dart';
import 'package:contact_card_builder/widgets/voice_capture_dialog.dart';
import 'package:contact_card_builder/services/storage_service.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('workspace cards, people and filters at width $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.setOnboardingCompleted(true);
      await storage.addDemoIdentityCardsOnce();
      await storage.addDemoConnectionsOnce();
      tester.view.physicalSize = Size(width, width < 1000 ? 640 : 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        ContactCardBuilderApp(storageService: storage, requireSignIn: false),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('One you.\nMany possibilities.'),
        width >= 1000 ? findsOneWidget : findsNothing,
      );
      expect(find.text('Integration Lead'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width >= 1000) {
        await tester.tap(find.text('Connections').first);
      } else {
        await tester.tap(find.byType(NavigationDestination).at(1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Amara Demo'), findsOneWidget);
      expect(find.text('Add a memory'), findsNothing);
      expect(find.text('Say it. Save it. Recall it.'), findsNothing);
      expect(find.byTooltip('Add connection'), findsNothing);
      expect(find.byTooltip('Receive a card'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final query = find.byType(TextField);
      await tester.ensureVisible(query);
      await tester.enterText(query, 'plumber');
      await tester.pumpAndSettle();
      expect(find.text('Owen Demo'), findsOneWidget);
      expect(find.text('Amara Demo'), findsNothing);
      final cue = find.byTooltip('Add memory for Owen Demo');
      await tester.ensureVisible(cue);
      await tester.tap(cue);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<VoiceCaptureDialog>(find.byType(VoiceCaptureDialog))
            .connection
            ?.fullName,
        'Owen Demo',
      );
      expect(find.widgetWithText(TextField, 'Name'), findsNothing);
      const memory = 'Explained a hidden water leak, wearing a red jacket.';
      await tester.enterText(
        find.widgetWithText(TextField, 'Say it in your own words'),
        memory,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final connections = await storage.loadConnections();
      expect(connections, hasLength(20));
      expect(
        connections.singleWhere((c) => c.fullName == 'Owen Demo').rawCue,
        memory,
      );

      if (width < 1000) {
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'plumber');
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.text('Owen Demo'), findsOneWidget);
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(320),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
