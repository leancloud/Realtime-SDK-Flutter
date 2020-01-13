package cn.leancloud.plugin;

import java.util.HashMap;

import cn.leancloud.im.v2.AVIMClient;
import cn.leancloud.im.v2.AVIMConversation;
import cn.leancloud.im.v2.AVIMMessage;
import cn.leancloud.im.v2.AVIMMessageHandler;

public class DefaultMessageHandler extends AVIMMessageHandler {

  private IMEventNotification listener;

  public DefaultMessageHandler(IMEventNotification listener) {
    this.listener = listener;
  }

  /**
   * 重载此方法来处理接收消息
   *
   * @param message
   * @param conversation
   * @param client
   */
  @Override
  public void onMessage(AVIMMessage message, AVIMConversation conversation, AVIMClient client) {
    if (null != this.listener) {
      HashMap<String, Object> param = new HashMap<>();
      param.put("clientId", client.getClientId());
      param.put("cid", conversation.getConversationId());
      param.put("message", Common.wrapMessage(message));
      this.listener.notify(Common.Method_Message_Received, param);
    }
  }

  /**
   * 重载此方法来处理消息回执
   *
   * @param message
   * @param conversation
   * @param client
   */
  @Override
  public void onMessageReceipt(AVIMMessage message, AVIMConversation conversation, AVIMClient client) {
    if (null != this.listener) {
      HashMap<String, Object> param = new HashMap<>();
      param.put("clientId", client.getClientId());
      param.put("cid", conversation.getConversationId());
      param.put("id", message.getMessageId());
      param.put("t", message.getDeliveredAt());
      param.put("read", false);
      this.listener.notify(Common.Method_Message_Receipted, param);
    }
  }
}
