# leancloud_official_plugin

An official flutter plugin for [LeanCloud](https://www.leancloud.cn) real-time message service based on [LeanCloud-Swift-SDK](https://github.com/leancloud/swift-sdk) and [LeanCloud-Java-SDK](https://github.com/leancloud/java-unified-sdk).

## Flutter Getting Started

This project is a starting point for a Flutter [plug-in package](https://flutter.dev/docs/development/packages-and-plugins),
a specialized package that includes platform-specific implementation code for Android and iOS.

For help getting started with Flutter, 
view [online documentation](https://flutter.dev/docs), 
which offers tutorials, samples, guidance on mobile development, and a full API reference.

## Usage

### Adding dependency

1. Following this [document](https://flutter.dev/docs/development/packages-and-plugins/using-packages) to add **leancloud_official_plugin** to your app, like this:

    ```
    dependencies:
      leancloud_official_plugin: '>=x.y.z <(x+1).0.0'    # Recommend using up-to-next-major policy.
    ```

2. Using [Gradle](https://gradle.org/) and [CocoaPods](https://cocoapods.org) to add platform-specific dependencies.

### Initialization

1. import `package:leancloud_official_plugin/leancloud_plugin.dart` in `lib/main.dart` of your project, like this:
    ```dart
    import 'package:leancloud_official_plugin/leancloud_plugin.dart';
    ```

2. import `cn.leancloud.AVOSCloud` and `cn.leancloud.AVLogger` in `YourApplication.java` of your project, then set up ***ID***, ***Key*** and ***URL***, like this:
    ```java
    import io.flutter.app.FlutterApplication;
    import cn.leancloud.AVOSCloud;
    import cn.leancloud.AVLogger;

    public class YourApplication extends FlutterApplication {
      @Override
      public void onCreate() {
        super.onCreate();
        AVOSCloud.setLogLevel(AVLogger.Level.DEBUG);
        AVOSCloud.initialize(this, YOUR_LC_APP_ID, YOUR_LC_APP_KEY, YOUR_LC_SERVER_URL);
      }
    }
    ```

3. import `LeanCloud` in `AppDelegate.swift` of your project, then set up ***ID***, ***Key*** and ***URL***, like this:
    ```swift
    import Flutter
    import LeanCloud

    @UIApplicationMain
    @objc class AppDelegate: FlutterAppDelegate {
      override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
      ) -> Bool {
        do {
          LCApplication.logLevel = .all
          try LCApplication.default.set(
            id: YOUR_LC_APP_ID,
            key: YOUR_LC_APP_KEY,
            serverURL: YOUR_LC_SERVER_URL)
          GeneratedPluginRegistrant.register(with: self)
          return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        } catch {
          fatalError("\(error)")
        }
      }
    }
    ```

### Run

After initialization, you can write some sample code and run it to check whether initializing success, like this:

```dart
// new an IM client
Client client = Client(id: CLIENT_ID);
// open it
await client.open();
```
