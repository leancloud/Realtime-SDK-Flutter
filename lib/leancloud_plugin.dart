import 'dart:async';

import 'package:flutter/services.dart';

class LeancloudPlugin {
  static const MethodChannel _channel =
      const MethodChannel('leancloud_plugin');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
