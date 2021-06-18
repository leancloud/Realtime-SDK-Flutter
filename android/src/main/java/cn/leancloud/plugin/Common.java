package cn.leancloud.plugin;


import cn.leancloud.im.v2.callback.LCIMConversationIterableResult;
import cn.leancloud.json.JSONObject;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import cn.leancloud.LCException;
import cn.leancloud.im.Signature;
import cn.leancloud.im.v2.LCIMClient;
import cn.leancloud.im.v2.LCIMConversation;
import cn.leancloud.im.v2.LCIMException;
import cn.leancloud.im.v2.LCIMMessage;
import cn.leancloud.im.v2.LCIMMessageInterval;
import cn.leancloud.im.v2.LCIMMessageOption;
import cn.leancloud.im.v2.LCIMMessageInterval.MessageIntervalBound;
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
  public static final String Method_Patch_Message = "patchMessage";
  public static final String Method_Get_Message_Receipt = "fetchReceiptTimestamp";
  public static final String Method_Query_Message = "queryMessage";
  public static final String Method_Query_Block_Members = "queryBlockedMembers";
  public static final String Method_Query_Mute_Members = "queryMutedMembers";
  public static final String Method_Update_Members = "updateMembers";
  public static final String Method_Update_Block_Members = "updateBlockMembers";
  public static final String Method_Update_Mute_Members = "updateMuteMembers";
  public static final String Method_Mute_Conversation = "muteToggle";
  public static final String Method_Update_Conversation = "updateData";
  public static final String Method_Query_Member_Count = "countMembers";

  public static final String Method_Client_Offline = "onSessionClose";
  public static final String Method_Client_Disconnected = "onSessionDisconnect";
  public static final String Method_Client_Resumed = "onSessionResume";
  public static final String Method_Client_Opened = "onSessionOpen";

  public static final String Method_Message_Received = "onMessageReceive";
  public static final String Method_Message_Receipted = "onMessageReceipt";
  public static final String Method_Message_Updated = "onMessagePatch";

  public static final String Method_Conv_Member_Updated = "onConversationMembersUpdate";
  public static final String Method_Conv_Updated = "onConversationDataUpdate";
  public static final String Method_Conv_UnreadCount_Updated = "onUnreadMessageCountUpdate";
  public static final String Method_Conv_LastReceipt_Timestamp_Updated = "onLastReceiptTimestampUpdate";

  public static final String Method_Sign_SessionOpen = "onSignSessionOpen";
  public static final String Method_Sign_Conversation = "onSignConversation";

  public static final String Param_Client_Id = "clientId";
  public static final String Param_ReOpen = "r";
  public static final String Param_Client_Tag = "tag";
  public static final String Param_Signature = "signRegistry";
  public static final String Param_Sign_SessionOpen = "sessionOpen";
  public static final String Param_Sign_Conversation = "conversation";
  public static final String Param_Conv_Type = "conv_type";
  public static final String Param_Conv_Members = "m";
  public static final String Param_Conv_Name = "name";
  public static final String Param_Conv_Attributes = "attr";
  public static final String Param_Conv_TTL = "ttl";
  public static final String Param_Conv_Id = "conversationId";

  public static final String Param_Conv_MaxACK_Timestamp = "maxAckTimestamp";
  public static final String Param_Conv_MaxRead_Timestamp = "maxReadTimestamp";

  public static final String Param_Unread_Mention = "unreadMessageMention";

  public static final String Param_Conv_Operation = "op";
  public static final String Param_Conv_Data = "data";
  public static final String Param_RawData = "rawData";
  public static final String Param_Count = "count";
  public static final String Param_Mention = "mention";
  public static final String Param_From = "from";

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
  public static final String Param_Query_Next = "next";

  public static final String Param_Message_Old = "oldMessage";
  public static final String Param_Message_New = "newMessage";
  public static final String Param_Message_Raw = "message";
  public static final String Param_Message_Options = "options";
  public static final String Param_Message_File = "file";
  public static final String Param_Message_Id = "id";
  public static final String Param_Message_Recall = "recall";
  public static final String Param_Message_Transient = "transient";

  public static final String Param_File_Path = "path";
  public static final String Param_File_Data = "data";
  public static final String Param_File_Url = "url";
  public static final String Param_File_Format = "format";
  public static final String Param_File_Name = "name";

  public static final String Param_Sign_TargetIds = "targetIds";
  public static final String Param_Sign_Action = "action";

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
  public static final String Conv_Operation_Block = "block";
  public static final String Conv_Operation_Unblock = "unblock";

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

  public static String getParamString(MethodCall call, String key) {
    if (call.hasArgument(key)) {
      return call.argument(key);
    }
    return null;
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
    LCException exception = new LCException(errorCode, message);
    return wrapException(exception);
  }

  public static Map<String, Object> wrapException(LCException ex) {
    if (null == ex) {
      return new HashMap<>();
    }
    Map<String, Object> error = new HashMap<>();
    if (ex instanceof LCIMException) {
      error.put("code", String.valueOf(((LCIMException) ex).getAppCode()));
    } else {
      error.put("code", String.valueOf(ex.getCode()));
    }
    error.put("message", ex.getMessage());
    if (null != ex.getCause()) {
      error.put("details", ex.getCause().getMessage());
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

  public static Map<String, Object> wrapClient(LCIMClient client) {
    HashMap<String, Object> result = new HashMap<>();
    if (null != client) {
      result.put("clientId", client.getClientId());
    }
    return result;
  }

  public static Map<String, Object> wrapMessage(LCIMMessage message) {
    Map<String, Object> result = new HashMap<>();
    if (null == message) {
      return result;
    }

    result = message.dumpRawData();
    return result;
  }

  public static LCIMMessage parseMessage(Map<String, Object> rawData) {
    if (null == rawData) {
      return null;
    }
    LCIMMessage message = LCIMMessage.parseJSON(rawData);
    return message;
  }

  public static LCIMMessageOption parseMessageOption(Map<String, Object> data) {
    if (null == data || data.isEmpty()) {
      return null;
    }
    LCIMMessageOption option = new LCIMMessageOption();
    if (data.containsKey("will")) {
      option.setWill((boolean) data.get("will"));
    }
    if (data.containsKey("receipt")) {
      option.setReceipt((boolean) data.get("receipt"));
    }
    if (data.containsKey("priority")) {
      int priority = (int) data.get("priority");
      option.setPriority(LCIMMessageOption.MessagePriority.getProiority(priority));
    }
    if (data.containsKey("pushData")) {
      option.setPushDataEx((Map<String, Object>) data.get("pushData"));
    }
    return option;
  }

  public static MessageIntervalBound parseMessageIntervalBound(Map<String, Object> data) {
    if (null == data) {
      return null;
    }
    String messageId = (String) data.get("id");
    long timestamp = (long) data.get("timestamp");
    boolean closed = (boolean) data.get("close");
    return LCIMMessageInterval.createBound(messageId, timestamp, closed);
  }

  public static Map<String, Object> wrapConversation(LCIMConversation conversation) {
    Map<String, Object> result = new HashMap<>();
    if (null == conversation) {
      return result;
    }

    result = conversation.dumpRawData();
    if (result.containsKey("conv_type") && result.containsKey("uniqueId") && !result.containsKey("unique")) {
      if (1 == (int) result.get("conv_type") && !StringUtil.isEmpty((String) result.get("uniqueId"))) {
        result.put("unique", true);
      }
    }

    return result;
  }
}
