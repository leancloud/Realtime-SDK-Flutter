package cn.leancloud.plugin;

import cn.leancloud.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import cn.leancloud.im.v2.LCIMClient;
import cn.leancloud.im.v2.LCIMConversation;
import cn.leancloud.im.v2.LCIMConversationEventHandler;
import cn.leancloud.im.v2.LCIMMessage;
import cn.leancloud.im.v2.conversation.LCIMConversationMemberInfo;
import cn.leancloud.utils.StringUtil;

public class DefaultConversationEventHandler extends LCIMConversationEventHandler {
  private static final String Member_Event_Self_Joined = "joined";
  private static final String Member_Event_Self_Left = "left";
  private static final String Member_Event_Other_Joined = "members-joined";
  private static final String Member_Event_Other_Left = "members-left";

  private static final String Member_Event_Self_Muted = "muted";
  private static final String Member_Event_Self_Unmuted = "unmuted";
  private static final String Member_Event_Other_Muted = "members-muted";
  private static final String Member_Event_Other_Unmuted = "members-unmuted";

  private static final String Member_Event_Self_Blocked = "blocked";
  private static final String Member_Event_Self_Unblocked = "unblocked";
  private static final String Member_Event_Other_Blocked = "members-blocked";
  private static final String Member_Event_Other_Unblocked = "members-unblocked";
  private IMEventNotification listener;


  public DefaultConversationEventHandler(IMEventNotification listener) {
    this.listener = listener;
  }

  /**
   * 实现本方法以处理聊天对话中的参与者离开事件
   *
   * @param client
   * @param conversation
   * @param members 离开的参与者
   * @param kickedBy 离开事件的发动者，有可能是离开的参与者本身
   * @since 3.0
   */

  public void onMemberLeft(LCIMClient client, LCIMConversation conversation,
                           List<String> members, String kickedBy) {
    LOGGER.d("Notification --- memberLeft. conversation:" + conversation.getConversationId());
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Other_Left);
      param.put(Common.Param_Conv_Members, members);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, kickedBy);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 实现本方法以处理聊天对话中的参与者加入事件
   *
   * @param client
   * @param conversation
   * @param members 加入的参与者
   * @param invitedBy 加入事件的邀请人，有可能是加入的参与者本身
   * @since 3.0
   */

  public void onMemberJoined(LCIMClient client, LCIMConversation conversation,
                             List<String> members, String invitedBy) {
    LOGGER.d("Notification --- memberJoined. conversation:" + conversation.getConversationId());
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Other_Joined);
      param.put(Common.Param_Conv_Members, members);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, invitedBy);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 实现本方法来处理当前用户被踢出某个聊天对话事件
   *
   * @param client
   * @param conversation
   * @param kickedBy 踢出你的人
   * @since 3.0
   */
  public void onKicked(LCIMClient client, LCIMConversation conversation, String kickedBy) {
    LOGGER.d("Notification --- " + " you are kicked from conversation:"
        + conversation.getConversationId() + " by " + kickedBy);
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Self_Left);
      param.put(Common.Param_Conv_Members, Arrays.asList(client.getClientId()));
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, kickedBy);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 实现本方法来处理当前用户被邀请到某个聊天对话事件
   *
   * @param client
   * @param conversation 被邀请的聊天对话
   * @param operator 邀请你的人
   * @since 3.0
   */
  public void onInvited(LCIMClient client, LCIMConversation conversation, String operator) {
    LOGGER.d("Notification --- " + " you are invited to conversation:"
        + conversation.getConversationId() + " by " + operator);
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Self_Joined);
      param.put(Common.Param_Conv_Members, Arrays.asList(client.getClientId()));
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 当前用户被禁言通知处理函数
   * @param client        聊天客户端
   * @param conversation  对话
   * @param operator      操作者 id
   */
  public void onMuted(LCIMClient client, LCIMConversation conversation, String operator) {
    LOGGER.d("Notification --- " + " you are muted by " + operator );
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Self_Muted);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 当前用户被解除禁言通知处理函数
   * @param client        聊天客户端
   * @param conversation  对话
   * @param operator      操作者 id
   */
  public void onUnmuted(LCIMClient client, LCIMConversation conversation, String operator) {
    LOGGER.d("Notification --- " + " you are unmuted by " + operator );
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Self_Unmuted);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 聊天室成员被禁言通知处理函数
   * @param client        聊天客户端
   * @param conversation  对话
   * @param members       成员列表
   * @param operator      操作者 id
   */
  public void onMemberMuted(LCIMClient client, LCIMConversation conversation, List<String> members, String operator){
    LOGGER.d("Notification --- " + operator + " muted members: " + StringUtil.join(", ", members));
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Other_Muted);
      param.put(Common.Param_Conv_Members, members);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 聊天室成员被解除禁言通知处理函数
   * @param client        聊天客户端
   * @param conversation  对话
   * @param members       成员列表
   * @param operator      操作者 id
   */
  public void onMemberUnmuted(LCIMClient client, LCIMConversation conversation,
                              List<String> members, String operator){
    LOGGER.d("Notification --- " + operator + " unmuted members: " + StringUtil.join(", ", members));
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Other_Unmuted);
      param.put(Common.Param_Conv_Members, members);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 当前用户被加入黑名单通知处理函数
   * @param client        聊天客户端
   * @param conversation  对话
   * @param operator      操作者 id
   */
  public void onBlocked(LCIMClient client, LCIMConversation conversation, String operator) {
    LOGGER.d("Notification --- " + " you are blocked by " + operator );
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Self_Blocked);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 当前用户被移出黑名单通知处理函数
   * @param client        聊天客户端
   * @param conversation  对话
   * @param operator      操作者 id
   */
  public void onUnblocked(LCIMClient client, LCIMConversation conversation, String operator) {
    LOGGER.d("Notification --- " + " you are unblocked by " + operator );
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Self_Unblocked);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 聊天室成员被加入黑名单通知处理函数
   * @param client        聊天客户端
   * @param conversation  对话
   * @param members       成员列表
   * @param operator      操作者 id
   */
  public void onMemberBlocked(LCIMClient client, LCIMConversation conversation,
                              List<String> members, String operator){
    LOGGER.d("Notification --- " + operator + " blocked members: " + StringUtil.join(", ", members));
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Other_Blocked);
      param.put(Common.Param_Conv_Members, members);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 聊天室成员被移出黑名单通知处理函数
   * @param client        聊天客户端
   * @param conversation  对话
   * @param members       成员列表
   * @param operator      操作者 id
   */
  public void onMemberUnblocked(LCIMClient client, LCIMConversation conversation,
                                List<String> members, String operator){
    LOGGER.d("Notification --- " + operator + " unblocked members: " + StringUtil.join(", ", members));
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Conv_Operation, Member_Event_Other_Unblocked);
      param.put(Common.Param_Conv_Members, members);
      param.put(Common.Param_Members, conversation.getMembers());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Member_Updated, param);
    }
  }

  /**
   * 实现本地方法来处理未读消息数量的通知
   * @param client
   * @param conversation
   */
  public void onUnreadMessagesCountUpdated(LCIMClient client, LCIMConversation conversation) {
    LOGGER.d("Notification --- unReadCount was updated. conversationId: " + conversation.getConversationId());
    if (null != this.listener) {
      HashMap<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Count, conversation.getUnreadMessagesCount());
      param.put(Common.Param_Mention, conversation.unreadMessagesMentioned());
      if (conversation.getUnreadMessagesCount() > 0 && null != conversation.getLastMessage()) {
        param.put(Common.Param_Message_Raw, Common.wrapMessage(conversation.getLastMessage()));
      }
      this.listener.notify(Common.Method_Conv_UnreadCount_Updated, param);
    }
  }

  /**
   * 实现本地方法来处理对方已经接收消息的通知
   */
  public void onLastDeliveredAtUpdated(LCIMClient client, LCIMConversation conversation) {
    LOGGER.d("Notification --- lastDeliveredAt was updated. conversationId: " + conversation.getConversationId());
    if (null != this.listener) {
      HashMap<String, Object> param = new HashMap<>();
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_MaxACK_Timestamp, conversation.getLastDeliveredAt());
      this.listener.notify(Common.Method_Conv_LastReceipt_Timestamp_Updated, param);
    }
  }

  /**
   * 实现本地方法来处理对方已经阅读消息的通知
   */
  public void onLastReadAtUpdated(LCIMClient client, LCIMConversation conversation) {
    LOGGER.d("Notification --- lastReadAt was updated. conversationId: " + conversation.getConversationId());
    if (null != this.listener) {
      HashMap<String, Object> param = new HashMap<>();
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_MaxRead_Timestamp, conversation.getLastReadAt());
      this.listener.notify(Common.Method_Conv_LastReceipt_Timestamp_Updated, param);
    }
  }

  /**
   * 实现本地方法来处理消息的更新事件
   * @param client
   * @param conversation
   * @param message
   */
  public void onMessageUpdated(LCIMClient client, LCIMConversation conversation, LCIMMessage message) {
    LOGGER.d("Notification --- message was updated. messageId: " + message.getMessageId());
    if (null != this.listener) {
      HashMap<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Message_Raw, Common.wrapMessage(message));
      //TODO: add patchCode and patchReason.
      this.listener.notify(Common.Method_Message_Updated, param);
    }
  }

  /**
   * 实现本地方法来处理消息的撤回事件
   * @param client
   * @param conversation
   * @param message
   */
  public void onMessageRecalled(LCIMClient client, LCIMConversation conversation, LCIMMessage message) {
    LOGGER.d("Notification --- message was recalled. messageId: " + message.getMessageId());
    if (null != this.listener) {
      HashMap<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Message_Raw, Common.wrapMessage(message));
      param.put(Common.Param_Message_Recall, true);
      this.listener.notify(Common.Method_Message_Updated, param);
    }
  }

  /**
   * 对话成员信息变更通知。
   * 常见的有：某成员权限发生变化（如，被设为管理员等）。
   * @param client             通知关联的 LCIMClient
   * @param conversation       通知关联的对话
   * @param memberInfo         变更后的成员信息
   * @param updatedProperties  发生变更的属性列表（当前固定为 "role"）
   * @param operator           操作者 id
   */
  public void onMemberInfoUpdated(LCIMClient client, LCIMConversation conversation,
                                  LCIMConversationMemberInfo memberInfo, List<String> updatedProperties, String operator) {
    LOGGER.d("Notification --- " + operator + " updated memberInfo: " + memberInfo.toString());
  }

  /**
   * 对话自身属性变更通知
   *
   * @param client
   * @param conversation
   * @param attr
   * @param operator
   */
  public void onInfoChanged(LCIMClient client, LCIMConversation conversation, JSONObject attr,
                            String operator) {
    LOGGER.d("Notification --- " + operator + " by member: " + operator + ", changedTo: " + attr.toJSONString());
    if (null != this.listener) {
      Map<String, Object> param = new HashMap<>();
      param.put(Common.Param_Client_Id, client.getClientId());
      param.put(Common.Param_Conv_Id, conversation.getConversationId());
      param.put(Common.Param_Operator, operator);
      param.put(Common.Param_Conv_Attributes, attr);
      param.put(Common.Param_RawData, Common.wrapConversation(conversation));
      param.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
      this.listener.notify(Common.Method_Conv_Updated, param);
    }
  }
}
