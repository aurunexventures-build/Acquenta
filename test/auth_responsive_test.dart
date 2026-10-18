import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:contact_card_builder/screens/auth_screen.dart';
import 'package:contact_card_builder/screens/policy_screen.dart';
import 'package:contact_card_builder/services/auth_service.dart';
import 'package:contact_card_builder/theme/metcue_theme.dart';
import 'auth_screen_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the fonts bundled with the running Flutter SDK when available.
    final fonts = Directory(
      '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
    );
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final file = File('${fonts.path}/${entry.value}');
      if (await file.exists()) {
        final loader = FontLoader(entry.key)
          ..addFont(file.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(360, 780),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('auth fits phone $size including safe areas and signup', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final auth = fixture.LoginAuth();
      addTearDown(auth.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            theme: MetCueTheme.light,
            home: RepaintBoundary(
              key: boundary,
              child: AuthScreen(onContinueOffline: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(
        scroll.maxScrollExtent,
        lessThanOrEqualTo(0.1),
        reason: 'Login should fit without scrolling at $size',
      );
      await tester.tap(find.text('New here? Create account'));
      await tester.pumpAndSettle();
      expect(
        scroll.maxScrollExtent,
        lessThanOrEqualTo(0.1),
        reason: 'Sign-up should fit without scrolling at $size',
      );
      expect(find.text('Privacy Policy').hitTestable(), findsOneWidget);
      expect(find.text('Terms of Use').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width == 360 && size.height == 780) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final picture = await render.toImage(pixelRatio: 2);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            'build/auth-phone-signup.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
    });
  }
  testWidgets('policies open in app and keep the signup draft', (tester) async {
    final auth = fixture.LoginAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          theme: MetCueTheme.light,
          home: AuthScreen(onContinueOffline: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New here? Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'draft@example.com',
    );
    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.byType(PolicyScreen), findsOneWidget);
    expect(find.text('Information you choose to save'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('draft@example.com'), findsOneWidget);
    await tester.ensureVisible(find.text('Terms of Use'));
    await tester.tap(find.text('Terms of Use'));
    await tester.pumpAndSettle();
    expect(find.text('Using Acquenta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'short landscape and large text keep controls reachable above keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final auth = fixture.LoginAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: auth,
          child: MaterialApp(
            theme: MetCueTheme.light,
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(
                ctx,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.tap(find.byType(TextFormField).last);
      tester.view.viewInsets = const FakeViewPadding(bottom: 150);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(TextFormField).last).bottom,
        lessThanOrEqualTo(210),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
