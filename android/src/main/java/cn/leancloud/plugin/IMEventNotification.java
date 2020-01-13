package cn.leancloud.plugin;

import io.flutter.plugin.common.MethodChannel;

public interface IMEventNotification {
  void notify(String method, Object param);
  void notifyWithResult(String method, Object param, MethodChannel.Result callback);
}
