package cn.leancloud.plugin;

import cn.leancloud.im.v2.AVIMClient;

public interface ClientStatusListener {
  void onDisconnected(AVIMClient client);
  void onResumed(AVIMClient client);
  void onOffline(AVIMClient client, int code);
}
