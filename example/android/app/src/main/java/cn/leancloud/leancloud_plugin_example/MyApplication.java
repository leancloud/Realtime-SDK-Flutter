package cn.leancloud.leancloud_plugin_example;

import android.app.NotificationManager;
import android.os.Build;

import cn.leancloud.AVLogger;
import cn.leancloud.AVOSCloud;
import cn.leancloud.im.AVIMOptions;
import cn.leancloud.push.PushService;
import io.flutter.app.FlutterApplication;

public class MyApplication extends FlutterApplication {

  private static final String LC_App_Id = "heQFQ0SwoQqiI3gEAcvKXjeR-gzGzoHsz";
  private static final String LC_App_Key = "lNSjPPPDohJjYMJcQSxi9qAm";
  private static final String LC_Server_Url = "https://heqfq0sw.lc-cn-n1-shared.com";

  private static final String defaultChannelId = "lc-default";
  private static final String defaultChannelName = "leancloud";

  @Override
  public void onCreate() {
    super.onCreate();
    AVOSCloud.setLogLevel(AVLogger.Level.DEBUG);
    AVOSCloud.initialize(this, LC_App_Id, LC_App_Key, LC_Server_Url);
    AVIMOptions.getGlobalOptions().setUnreadNotificationEnabled(true);

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      PushService.createNotificationChannel(this, defaultChannelId, defaultChannelName,
              "leancloud notification", NotificationManager.IMPORTANCE_DEFAULT,
              false, 0, false, null);
      PushService.setDefaultChannelId(this, defaultChannelId);
    }

    PushService.setDefaultPushCallback(this, MainActivity.class);
  }
}
