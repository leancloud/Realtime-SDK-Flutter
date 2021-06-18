package cn.leancloud.leancloud_plugin_example;

import android.app.NotificationManager;
import android.os.Build;

import cn.leancloud.LCLogger;
import cn.leancloud.LeanCloud;
import cn.leancloud.im.LCIMOptions;
import cn.leancloud.push.PushService;
import io.flutter.app.FlutterApplication;

public class MyApplication extends FlutterApplication {
//  private static final String LC_App_Id = "s0g5kxj7ajtf6n2wt8fqty18p25gmvgrh7b430iuugsde212";
//  private static final String LC_App_Key = "hc7jpfubg5vaurjlezxhfr1t9pqb9w8tfw0puz1g83vl9nwz";
//  private static final String LC_Server_Url = "https://s0g5kxj7.lc-cn-n1-shared.com";

  private static final String LC_App_Id = "heQFQ0SwoQqiI3gEAcvKXjeR-gzGzoHsz";
  private static final String LC_App_Key = "lNSjPPPDohJjYMJcQSxi9qAm";
  private static final String LC_Server_Url = "https://heqfq0sw.lc-cn-n1-shared.com";

  private static final String defaultChannelId = "lc-default";
  private static final String defaultChannelName = "leancloud";
  @Override
  public void onCreate() {
    super.onCreate();
    LeanCloud.setLogLevel(LCLogger.Level.DEBUG);
    LeanCloud.initialize(this, LC_App_Id, LC_App_Key, LC_Server_Url);
    LCIMOptions.getGlobalOptions().setUnreadNotificationEnabled(true);

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      PushService.createNotificationChannel(this, defaultChannelId, defaultChannelName,
          "leancloud notification", NotificationManager.IMPORTANCE_DEFAULT,
          false, 0, false, null);
      PushService.setDefaultChannelId(this, defaultChannelId);
    }

    PushService.setDefaultPushCallback(this, MainActivity.class);
  }
}
