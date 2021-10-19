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

    * Using *CocoaPods* in *terminal*
      * do `$ cd ios/` 
      * then `$ pod update` or `$ pod install --repo-update`
    * *Gradle*
      * [reference](https://leancloud.cn/docs/sdk_setup-java.html#hash260111001)

### Initialization

1. import `package:leancloud_official_plugin/leancloud_plugin.dart` in `lib/main.dart` of your project, like this:
    ```dart
    import 'package:leancloud_official_plugin/leancloud_plugin.dart';
    ```

2. import `cn.leancloud.LeanCloud`, `cn.leancloud.LCLogger` and `cn.leancloud.im.LCIMOptions` in `YourApplication.java` of your project, then set up ***ID***, ***Key*** and ***URL***, like this:
    ```java
    import io.flutter.app.FlutterApplication;
    import cn.leancloud.LeanCloud;
    import cn.leancloud.LCLogger;
    import cn.leancloud.im.LCIMOptions;

    public class YourApplication extends FlutterApplication {
      @Override
      public void onCreate() {
        super.onCreate();
        LCIMOptions.getGlobalOptions().setUnreadNotificationEnabled(true);
        LeanCloud.setLogLevel(LCLogger.Level.DEBUG);
        LeanCloud.initialize(this, YOUR_LC_APP_ID, YOUR_LC_APP_KEY, YOUR_LC_SERVER_URL);
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

### Push setup (optional)

Due to different push service in iOS and Android, the setup-code should be wrote in native platform. 
it's optional, so if you no need of push service, you can ignore this section.

* iOS

    ```swift
    import Flutter
    import LeanCloud
    import UserNotifications

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
                /*
                register APNs to access token, like this:
                */ 
                UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                    switch settings.authorizationStatus {
                    case .authorized:
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    case .notDetermined:
                        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { (granted, error) in
                            if granted {
                                DispatchQueue.main.async {
                                    UIApplication.shared.registerForRemoteNotifications()
                                }
                            }
                        }
                    default:
                        break
                    }
                }
                return super.application(application, didFinishLaunchingWithOptions: launchOptions)
            } catch {
                fatalError("\(error)")
            }
        }
        
        override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
            /*
            set APNs deviceToken and Team ID.
            */
            LCApplication.default.currentInstallation.set(
                deviceToken: deviceToken,
                apnsTeamId: YOUR_APNS_TEAM_ID)
            /*
            save to LeanCloud.
            */
            LCApplication.default.currentInstallation.save { (result) in
                switch result {
                case .success:
                    break
                case .failure(error: let error):
                    print(error)
                }
            }
        }

        override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
            super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
            print(error)
        }
    }
    ```

* Android 

    [reference](https://leancloud.cn/docs/android_push_guide.html)

## Sample Code

After initialization, you can write some sample code and run it to check whether initializing success, like this:

### Open

```dart
// new an IM client
Client client = Client(id: CLIENT_ID);
// open it
await client.open();
```

### Query Conversations

```dart
// the ID of the conversation instance list
List<String> objectIDs = [...];
// new query from an opened client
ConversationQuery query = client.conversationQuery();
// set query condition
query.whereContainedIn(
  'objectId',
  objectIDs,
);
query.limit = objectIDs.length;
// do the query
List<Conversation> conversations = await query.find();
```
