package cn.leancloud.leancloud_plugin_example;

import cn.leancloud.AVLogger;
import cn.leancloud.AVOSCloud;
import io.flutter.app.FlutterApplication;

public class MyApplication extends FlutterApplication {
  private static final String LC_App_Id = "ohqhxu3mgoj2eyj6ed02yliytmbes3mwhha8ylnc215h0bgk";
  private static final String LC_App_Key = "6j8fuggqkbc5m86b8mp4pf2no170i5m7vmax5iypmi72wldc";
  private static final String LC_Server_Url = "https://ohqhxu3m.lc-cn-n1-shared.com";

  @Override
  public void onCreate() {
    super.onCreate();
    AVOSCloud.setLogLevel(AVLogger.Level.DEBUG);
    AVOSCloud.initialize(this, LC_App_Id, LC_App_Key, LC_Server_Url);
  }
}
