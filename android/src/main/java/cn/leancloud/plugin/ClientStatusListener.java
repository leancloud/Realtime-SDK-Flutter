package cn.leancloud.plugin;

import cn.leancloud.im.v2.LCIMClient;

public interface ClientStatusListener {
  void onDisconnected(LCIMClient client);
  void onResumed(LCIMClient client);
  void onOffline(LCIMClient client, int code);
}
