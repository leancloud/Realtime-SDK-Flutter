import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancloud_plugin/leancloud_plugin.dart';

void main() {
  const MethodChannel channel = MethodChannel('leancloud_plugin');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await LeancloudPlugin.platformVersion, '42');
  });
}
