package cn.leancloud.leancloud_plugin_example;

import cn.leancloud.AVLogger;
import cn.leancloud.AVOSCloud;
import io.flutter.app.FlutterApplication;

public class MyApplication extends FlutterApplication {
  private static final String LC_App_Id = "s0g5kxj7ajtf6n2wt8fqty18p25gmvgrh7b430iuugsde212";
  private static final String LC_App_Key = "hc7jpfubg5vaurjlezxhfr1t9pqb9w8tfw0puz1g83vl9nwz";
  private static final String LC_Server_Url = "https://s0g5kxj7.lc-cn-n1-shared.com";

  @Override
  public void onCreate() {
    super.onCreate();
    AVOSCloud.setLogLevel(AVLogger.Level.DEBUG);
    AVOSCloud.initialize(this, LC_App_Id, LC_App_Key, LC_Server_Url);
  }
}
