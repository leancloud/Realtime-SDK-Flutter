package cn.leancloud.plugin;

import java.util.HashMap;
import java.util.Map;

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
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      Map<String, Object> msgData = Common.wrapMessage(message);
      msgData.put(Common.Param_Client_Id, client.getClientId());
      msgData.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Message_Raw, msgData);
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
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Message_Id, message.getMessageId());
      param.put(Common.Param_Timestamp, message.getDeliveredAt());
      param.put(Common.Param_Flag_Read, false);
      this.listener.notify(Common.Method_Message_Receipted, param);
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
  public void onMessageReceiptEx(AVIMMessage message, String operator, AVIMConversation conversation, AVIMClient client) {
    if (null != this.listener) {
      HashMap<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Message_Id, message.getMessageId());
      param.put(Common.Param_Timestamp, message.getDeliveredAt());
      param.put(Common.Param_From, operator);
      param.put(Common.Param_Flag_Read, false);
      this.listener.notify(Common.Method_Message_Receipted, param);
    }
  }
}
