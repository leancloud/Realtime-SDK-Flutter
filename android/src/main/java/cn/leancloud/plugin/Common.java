package cn.leancloud.plugin;

import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import cn.leancloud.AVException;
import cn.leancloud.AVFile;
import cn.leancloud.im.Signature;
import cn.leancloud.im.v2.AVIMBinaryMessage;
import cn.leancloud.im.v2.AVIMClient;
import cn.leancloud.im.v2.AVIMConversation;
import cn.leancloud.im.v2.AVIMException;
import cn.leancloud.im.v2.AVIMMessage;
import cn.leancloud.im.v2.AVIMMessageInterval;
import cn.leancloud.im.v2.AVIMMessageOption;
import cn.leancloud.im.v2.AVIMTypedMessage;
import cn.leancloud.im.v2.messages.AVIMFileMessage;
import cn.leancloud.im.v2.messages.AVIMLocationMessage;
import cn.leancloud.im.v2.messages.AVIMTextMessage;
import cn.leancloud.im.v2.AVIMMessageInterval.AVIMMessageIntervalBound;
import cn.leancloud.ops.Utils;
import cn.leancloud.types.AVGeoPoint;
import cn.leancloud.utils.StringUtil;
import io.flutter.plugin.common.MethodCall;

public class Common {
  public static final String Method_Close_Client = "closeClient";
  public static final String Method_Open_Client = "openClient";
  public static final String Method_Create_Conversation = "createConversation";
  public static final String Method_Fetch_Conversation = "getConversation";
  public static final String Method_Query_Conversation = "queryConversation";
  public static final String Method_Send_Message = "sendMessage";
  public static final String Method_Read_Message = "readMessage";
  public static final String Method_Update_Message = "updateMessage";
  public static final String Method_Get_Message_Receipt = "getMessageReceipt";
  public static final String Method_Query_Message = "queryMessage";
  public static final String Method_Update_Members = "updateMembers";
  public static final String Method_Mute_Conversation = "muteToggle";
  public static final String Method_Update_Conversation = "updateData";
  public static final String Method_Query_Member_Count = "getMembersCount";

  public static final String Method_Client_Offline = "onSessionClose";
  public static final String Method_Client_Disconnected = "onSessionDisconnect";
  public static final String Method_Client_Resumed = "onSessionResume";

  public static final String Method_Message_Received = "onMessageReceive";
  public static final String Method_Message_Receipted = "onMessageReceipt";
  public static final String Method_Message_Updated = "onMessageUpdate";

  public static final String Method_Conv_Member_Updated = "onConversationMembersUpdate";
  public static final String Method_Conv_Updated = "onConversationDataUpdate";
  public static final String Method_Conv_UnreadCount_Updated = "onUnreadMessageCountUpdate";

  public static final String Param_Client_Id = "clientId";
  public static final String Param_ReOpen = "r";
  public static final String Param_Client_Tag = "tag";
  public static final String Param_Signature = "sign";
  public static final String Param_Conv_Type = "conv_type";
  public static final String Param_Conv_Members = "m";
  public static final String Param_Conv_Name = "name";
  public static final String Param_Conv_Attributes = "attr";
  public static final String Param_Conv_TTL = "ttl";
  public static final String Param_Conv_Id = "conversationId";

  public static final String Param_Conv_Operation = "op";
  public static final String Param_Conv_Data = "data";
  public static final String Param_RawData = "rawData";
  public static final String Param_Count = "count";
  public static final String Param_Mention = "mention";

  public static final String Param_Timestamp = "t";
  public static final String Param_Flag_Read = "read";
  public static final String Param_Patch_Code = "patchCode";
  public static final String Param_Patch_Reason = "patchReason";
  public static final String Param_Members = "members";
  public static final String Param_Operator = "initBy";
  public static final String Param_Update_Time = "udate";

  public static final String Param_Query_Where = "where";
  public static final String Param_Query_Sort = "sort";
  public static final String Param_Query_Limit = "limit";
  public static final String Param_Query_Skip = "skip";
  public static final String Param_Query_Flag = "flag";
  public static final String Param_Query_Temp_List = "tempConvIds";

  public static final String Param_Query_Start = "start";
  public static final String Param_Query_End = "end";
  public static final String Param_Query_Direction = "direction";
  public static final String Param_Query_MsgType = "type";

  public static final String Param_Message_Old = "oldMessage";
  public static final String Param_Message_New = "newMessage";
  public static final String Param_Message_Raw = "message";
  public static final String Param_Message_Options = "options";
  public static final String Param_Message_File = "file";
  public static final String Param_Message_Id = "id";

  public static final String Param_Code = "code";
  public static final String Param_Error = "error";

  public static final int Conv_Type_Unique = 0;
  public static final int Conv_Type_Common = 1;
  public static final int Conv_Type_Transient = 2;
  public static final int Conv_Type_Temporary = 4;

  public static final String Conv_Operation_Mute = "mute";
  public static final String Conv_Operation_Unmute = "unmute";
  public static final String Conv_Operation_Add = "add";
  public static final String Conv_Operation_Remove = "remove";

  public static <T> T getMethodParam(MethodCall call, String key) {
    if (call.hasArgument(key)) {
      return call.argument(key);
    }
    return null;
  }

  public static boolean getParamBoolean(MethodCall call, String key) {
    if (call.hasArgument(key)) {
      return call.argument(key);
    }
    return false;
  }

  public static int getParamInt(MethodCall call, String key) {
    if (call.hasArgument(key)) {
      return call.argument(key);
    }
    return 0;
  }

  public static Signature getMethodSignature(MethodCall call, String key) {
    Map<String, Object> param = getMethodParam(call, key);
    if (null == param) {
      return null;
    }
    Signature result = new Signature();
    result.setSignature((String) param.get("s"));
    result.setNonce((String) param.get("n"));
    result.setTimestamp((long) param.get("t"));
    return result;
  }

  public static Map<String, Object> wrapException(int errorCode, String message) {
    AVException exception = new AVException(errorCode, message);
    return wrapException(exception);
  }

  public static Map<String, Object> wrapException(AVException ex) {
    if (null == ex) {
      return new HashMap<>();
    }
    Map<String, Object> error = new HashMap<>();
    if (ex instanceof AVIMException) {
      error.put("code", String.valueOf(((AVIMException)ex).getAppCode()));
    } else {
      error.put("code", String.valueOf(ex.getCode()));
    }
    error.put("message", ex.getMessage());
    if (null != ex.getCause()) {
      error.put("details", ex.getCause());
    }
    Map<String, Object> result = new HashMap<>();
    result.put("error", error);
    return result;
  }

  public static Map<String, Object> wrapSuccessResponse(Map<String, Object> result) {
    Map<String, Object> response = new HashMap<>();
    if (null != result) {
      response.put("success", result);
    }
    return response;
  }

  public static Map<String, Object> wrapSuccessResponse(List<Map<String, Object>> resultList) {
    Map<String, Object> response = new HashMap<>();
    if (null != resultList) {
      response.put("success", resultList);
    }
    return response;
  }

  public static Map<String, Object> wrapSuccessResponse(int result) {
    Map<String, Object> response = new HashMap<>();
    response.put("success", result);
    return response;
  }

  public static Map<String, Object> wrapClient(AVIMClient client) {
    HashMap<String, Object> result = new HashMap<>();
    if (null != client) {
      result.put("clientId", client.getClientId());
    }
    return result;
  }

  public static Map<String, Object> wrapTypedMessage(AVIMTypedMessage message) {
    HashMap<String, Object> result = new HashMap<>();
    if (null == message) {
      return result;
    }

    result.put("_lctype", message.getMessageType());

    String text = null;
    Map<String, Object> attributes = null;
    Map<String, Object> fileInstance = null;
    Map<String, Object> locationInstance = null;
    if (message instanceof AVIMTextMessage) {
      text = ((AVIMTextMessage)message).getText();
      attributes = ((AVIMTextMessage)message).getAttrs();
    } else if (message instanceof AVIMFileMessage) {
      text = ((AVIMFileMessage) message).getText();
      attributes = ((AVIMFileMessage) message).getAttrs();
      AVFile avFile = ((AVIMFileMessage) message).getAVFile();

      fileInstance = new HashMap<String, Object>();
      if (null != avFile) {
        fileInstance.put("objId", avFile.getObjectId());
        fileInstance.put("url", avFile.getUrl());
      }
      fileInstance.put("metaData", ((AVIMFileMessage) message).getFileMetaData());
    } else if (message instanceof AVIMLocationMessage) {
      text = ((AVIMLocationMessage) message).getText();
      attributes = ((AVIMLocationMessage) message).getAttrs();
      AVGeoPoint geoPoint = ((AVIMLocationMessage) message).getLocation();
      if (null != geoPoint) {
        locationInstance = new HashMap<>();
        locationInstance.put("latitude", geoPoint.getLatitude());
        locationInstance.put("longitude", geoPoint.getLongitude());
      }
    } else {
      text = message.getContent();
    }
    if (!StringUtil.isEmpty(text)) {
      result.put("_lctext", text);
    }
    if (null != attributes) {
      result.put("_lcattrs", attributes);
    }
    if (null != fileInstance) {
      result.put("_lcfile", fileInstance);
    }
    if (null != locationInstance) {
      result.put("_lcloc", locationInstance);
    }
    return result;
  }

  public static Map<String, Object> wrapMessage(AVIMMessage message) {
    Map<String, Object> result = new HashMap<>();
    if (null == message) {
      return result;
    }

    if (!StringUtil.isEmpty(message.getMessageId())) {
      result.put("id", message.getMessageId());
    }
    String conversationId = message.getConversationId();
    if (!StringUtil.isEmpty(conversationId)) {
      result.put("cid", conversationId);
    }
    String from = message.getFrom();
    if (!StringUtil.isEmpty(from)) {
      result.put("from", from);
    }
    long timestamp = message.getTimestamp();
    if (timestamp > 0l) {
      result.put("timestamp", timestamp);
    }
    long patchTimestamp = message.getUpdateAt();
    if (patchTimestamp > 0l) {
      result.put("patchTimestamp", patchTimestamp);
    }
    long deliverTimestamp = message.getDeliveredAt();
    if (deliverTimestamp > 0l) {
      result.put("ackAt", deliverTimestamp);
    }
    long readTimestamp = message.getReadAt();
    if (readTimestamp > 0l) {
      result.put("readAt", readTimestamp);
    }
    boolean mentionAll = message.isMentionAll();
    if (mentionAll) {
      result.put("mentionAll", mentionAll);
    }
    List<String> mentionList = message.getMentionList();
    if (null != mentionList && mentionList.size() > 0) {
      result.put("mentionPids", mentionList);
    }
    if (message instanceof AVIMTypedMessage) {
      AVIMTypedMessage typedMessage = (AVIMTypedMessage) message;
      result.put("typeMsgData", wrapTypedMessage(typedMessage));
    } else if (message instanceof AVIMBinaryMessage) {
      AVIMBinaryMessage binaryMessage = (AVIMBinaryMessage) message;
      result.put("binaryMsg", binaryMessage.getBytes());
    } else {
      String content = message.getContent();
      if (null != content) {
        result.put("msg", content);
      }
    }

    return result;
  }

  public static AVIMMessage parseMessage(Map<String, Object> rawData) {
    if (null == rawData) {
      return null;
    }
    AVIMMessage message;
    if (rawData.containsKey("typeMsgData")) {
      message = new AVIMTypedMessage();
    } else if (rawData.containsKey("binaryMsg")) {
      message = new AVIMBinaryMessage();
      ((AVIMBinaryMessage)message).setBytes((byte[]) rawData.get("binaryMsg"));
    } else  {
      message = new AVIMMessage();
      if (rawData.containsKey("msg")) {
        String content = (String) rawData.get("msg");
        message.setContent(content);
      }
    }
    if (rawData.containsKey("cid")) {
      message.setConversationId((String) rawData.get("cid"));
    }
    if (rawData.containsKey("from")) {
      message.setFrom((String) rawData.get("from"));
    }
    if (rawData.containsKey("mentionAll")) {
      message.setMentionAll((boolean) rawData.get("mentionAll"));
    }
    if (rawData.containsKey("mentionPids")) {
      message.setMentionList((List<String>) rawData.get("mentionPids"));
    }
    if (rawData.containsKey("id")) {
      message.setMessageId((String) rawData.get("id"));
    }
    if (rawData.containsKey("timestamp")) {
      message.setTimestamp((long) rawData.get("timestamp"));
    }
    if (rawData.containsKey("ackAt")) {
      message.setReceiptTimestamp((long)rawData.get("ackAt"));
    }
    if (rawData.containsKey("readAt")) {
      message.setReadAt((long) rawData.get("readAt"));
    }

    return message;
  }

  public static AVIMMessageOption parseMessageOption(Map<String, Object> data) {
    if (null == data || data.isEmpty()) {
      return null;
    }
    AVIMMessageOption option = new AVIMMessageOption();
    if (data.containsKey("will")) {
      option.setWill((boolean) data.get("will"));
    }
    if (data.containsKey("receipt")) {
      option.setReceipt((boolean) data.get("receipt"));
    }
    if (data.containsKey("priority")) {
      int priority = (int)data.get("priority");
      option.setPriority(AVIMMessageOption.MessagePriority.getProiority(priority));
    }
    if (data.containsKey("pushData")) {
      option.setPushDataEx((Map<String, Object>)data.get("pushData"));
    }
    return option;
  }

  public static AVIMMessageIntervalBound parseMessageIntervalBound(Map<String, Object> data) {
    if (null == data) {
      return null;
    }
    String messageId = (String) data.get("id");
    long timestamp = (long) data.get("timestamp");
    boolean closed = (boolean) data.get("close");
    return AVIMMessageInterval.createBound(messageId, timestamp, closed);
  }

  public static Map<String, Object> wrapConversation(AVIMConversation conversation) {
    HashMap<String, Object> result = new HashMap<>();
    if (null == conversation) {
      return result;
    }
    String conversationId = conversation.getConversationId();
    String creator = conversation.getCreator();
    Map<String, Object> attr = conversation.getAttributes();
    String name = conversation.getName();
    Date createdAt = conversation.getCreatedAt();
    Date updatedAt = conversation.getUpdatedAt();
    List<String> members = conversation.getMembers();
    boolean isSystem = conversation.isSystem();
    boolean isTemporary = conversation.isTemporary();
    boolean isTransient = conversation.isTransient();
    int type = conversation.getType();
    AVIMMessage lastMsg = conversation.getLastMessage();
    String uniqueId = conversation.getUniqueId();
    Date lastMsgAt = conversation.getLastMessageAt();

    result.put("objectId", conversationId);
    result.put("c", creator);
    if (!StringUtil.isEmpty(name)) {
      result.put("name", name);
    }
    if (!StringUtil.isEmpty(uniqueId)) {
      result.put("uniqueId", uniqueId);
      result.put("unique", true);
    } else {
      result.put("unique", false);
    }

    if (null != attr && !attr.isEmpty()) {
      result.put("attr", attr);
    }
    if (null != createdAt) {
      result.put("createdAt", StringUtil.stringFromDate(createdAt));
    }
    if (null != updatedAt) {
      result.put("updatedAt", StringUtil.stringFromDate(updatedAt));
    }
    result.put("conv_type", type);
    result.put("tr", isTransient);
    result.put("sys", isSystem);
    result.put("temp", isTemporary);
    if (isTemporary) {
      result.put("ttl", conversation.getTemporaryExpiredat());
    }
    if (null != members) {
      result.put("m", members);
    }

    if (null != lastMsgAt) {
      result.put("lm", Utils.mapFromDate(lastMsgAt));
    }

    if (null != lastMsg) {
      result.put("msg", lastMsg.getContent());
    }

    return result;
  }
}
