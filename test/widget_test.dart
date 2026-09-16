import 'package:flutter_test/flutter_test.dart';
import 'package:cinemark/main.dart';
import 'package:cinemark/views/1_splash/splash_view.dart';

void main() {
  testWidgets('App renders SplashView successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const CinemarkApp());
    expect(find.byType(SplashView), findsOneWidget);
  });
}
