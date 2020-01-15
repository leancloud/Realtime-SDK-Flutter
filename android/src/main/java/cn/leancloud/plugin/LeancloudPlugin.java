package cn.leancloud.plugin;

import android.util.Log;

import com.alibaba.fastjson.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import androidx.annotation.NonNull;
import cn.leancloud.AVException;
import cn.leancloud.im.v2.AVIMClient;
import cn.leancloud.im.v2.AVIMClientOpenOption;
import cn.leancloud.im.v2.AVIMConversation;
import cn.leancloud.im.v2.AVIMConversationsQuery;
import cn.leancloud.im.v2.AVIMException;
import cn.leancloud.im.v2.AVIMMessage;
import cn.leancloud.im.v2.AVIMMessageInterval;
import cn.leancloud.im.v2.AVIMMessageInterval.AVIMMessageIntervalBound;
import cn.leancloud.im.v2.AVIMMessageManager;
import cn.leancloud.im.v2.AVIMMessageOption;
import cn.leancloud.im.v2.AVIMMessageQueryDirection;
import cn.leancloud.im.v2.callback.AVIMClientCallback;
import cn.leancloud.im.v2.callback.AVIMConversationCallback;
import cn.leancloud.im.v2.callback.AVIMConversationCreatedCallback;
import cn.leancloud.im.v2.callback.AVIMConversationMemberCountCallback;
import cn.leancloud.im.v2.callback.AVIMConversationQueryCallback;
import cn.leancloud.im.v2.callback.AVIMMessageUpdatedCallback;
import cn.leancloud.im.v2.callback.AVIMMessagesQueryCallback;
import cn.leancloud.utils.StringUtil;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/** LeancloudPlugin */
public class LeancloudPlugin implements FlutterPlugin, MethodCallHandler,
    ClientStatusListener, IMEventNotification {
  private final static String TAG = LeancloudPlugin.class.getSimpleName();
  private final static LeancloudPlugin _INSTANCE = new LeancloudPlugin();
  private static MethodChannel _CHANNEL = null;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    Log.d(TAG, "LeancloudPlugin.onAttachedToEngine called.");
    _initialize(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "leancloud_plugin");
  }

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  public static void registerWith(Registrar registrar) {
    Log.d(TAG, "LeancloudPlugin#registerWith called.");
    _initialize(registrar.messenger(), "leancloud_plugin");
  }

  private static void _initialize(BinaryMessenger messenger, String name) {
    if (null == _CHANNEL) {
      _CHANNEL = new MethodChannel(messenger, "leancloud_plugin");
      _CHANNEL.setMethodCallHandler(_INSTANCE);

      AVIMMessageManager.registerDefaultMessageHandler(new DefaultMessageHandler(_INSTANCE));
      AVIMMessageManager.setConversationEventHandler(new DefaultConversationEventHandler(_INSTANCE));
      AVIMClient.setClientEventHandler(new DefaultClientEventHandler(_INSTANCE));
    }
  }

  // TODO: support signature on other way.
  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull final Result result) {
    Log.d(TAG, "onMethodCall " + call.method);

    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
      return;
    }

    String clientId = Common.getMethodParam(call, Common.Param_Client_Id);
    if (StringUtil.isEmpty(clientId)) {
      result.success(Common.wrapException(Exception.ErrorCode_Invalid_Parameter,
          Exception.ErrorMsg_Invalid_ClientId));
      return;
    }

    if (call.method.equals(Common.Method_Open_Client)) {
      String tag = Common.getMethodParam(call, Common.Param_Client_Tag);
      boolean reconnectFlag = Common.getParamBoolean(call, Common.Param_ReOpen);
      AVIMClientOpenOption openOption = new AVIMClientOpenOption();
      if (reconnectFlag) {
        openOption.setReconnect(true);
      }
      AVIMClient client = StringUtil.isEmpty(tag) ?
          AVIMClient.getInstance(clientId) : AVIMClient.getInstance(clientId, tag);
      client.open(openOption, new AVIMClientCallback() {
        @Override
        public void done(AVIMClient client, AVIMException e) {
          Log.d(TAG, "client open result: " + client);
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            result.success(Common.wrapSuccessResponse(Common.wrapClient(client)));
          }
        }
      });
      return;
    }

    AVIMClient avimClient = AVIMClient.getInstance(clientId);

    if (call.method.equals(Common.Method_Close_Client)) {
      avimClient.close(new AVIMClientCallback() {
        @Override
        public void done(AVIMClient client, AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            result.success(Common.wrapSuccessResponse(Common.wrapClient(client)));
          }
        }
      });
      return;
    }

    if (call.method.equals(Common.Method_Create_Conversation)) {
      int convType = Common.getParamInt(call, Common.Param_Conv_Type);
      List<String> members = Common.getMethodParam(call, Common.Param_Conv_Members);
      String name = Common.getMethodParam(call, Common.Param_Conv_Name);
      Map<String, Object> attr = Common.getMethodParam(call, Common.Param_Conv_Attributes);
      int ttl = Common.getParamInt(call, Common.Param_Conv_TTL);
      AVIMConversationCreatedCallback callback = new AVIMConversationCreatedCallback() {
        @Override
        public void done(AVIMConversation conversation, AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> convData = Common.wrapConversation(conversation);
            Log.d(TAG, "succeed create conv:" + new JSONObject(convData).toJSONString());
            result.success(Common.wrapSuccessResponse(convData));
          }
        }
      };
      switch (convType) {
        case Common.Conv_Type_Unique:
          avimClient.createConversation(members, name, attr, false, true, callback);
          break;
        case Common.Conv_Type_Temporary:
          avimClient.createTemporaryConversation(members, ttl, callback);
          break;
        case Common.Conv_Type_Transient:
          avimClient.createConversation(members, name, attr, true, callback);
          break;
        case Common.Conv_Type_Common:
        default:
          avimClient.createConversation(members, name, attr, callback);
          break;
      }
      return;
    }

    if (call.method.equals(Common.Method_Query_Conversation)) {
      String where = Common.getMethodParam(call, Common.Param_Query_Where);
      String sort = Common.getMethodParam(call, Common.Param_Query_Sort);
      int limit = Common.getParamInt(call, Common.Param_Query_Limit);
      int skip = Common.getParamInt(call, Common.Param_Query_Skip);
      int flag = Common.getParamInt(call, Common.Param_Query_Flag);
      List<String> tempConvIds = Common.getMethodParam(call, Common.Param_Query_Temp_List);
      AVIMConversationQueryCallback callback = new AVIMConversationQueryCallback() {
        @Override
        public void done(List<AVIMConversation> conversations, AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            List<Map<String, Object>> queryResult = new ArrayList<>();
            for (AVIMConversation conv: conversations) {
              queryResult.add(Common.wrapConversation(conv));
            }
            result.success(Common.wrapSuccessResponse(queryResult));
          }
        }
      };
      AVIMConversationsQuery query = avimClient.getConversationsQuery();
      if (null == tempConvIds || tempConvIds.isEmpty()) {
        query.directFindInBackground(where, sort, skip, limit, flag, callback);
      } else {
        query.findTempConversationsInBackground(tempConvIds, callback);
      }
      return;
    }

    String conversationId = Common.getMethodParam(call, Common.Param_Conv_Id);
    final AVIMConversation conversation = avimClient.getConversation(conversationId);
    if (call.method.equals(Common.Method_Fetch_Conversation)) {
      result.success(Common.wrapSuccessResponse(Common.wrapConversation(conversation)));
      return;
    }

    if (null == conversation) {
      result.success(Common.wrapException(Exception.ErrorCode_Invalid_Parameter,
          Exception.ErrorMsg_Invalid_ConversationId));
      return;
    }

    if (call.method.equals(Common.Method_Mute_Conversation)) {
      String operation = Common.getMethodParam(call, Common.Param_Conv_Operation);
      AVIMConversationCallback callback = new AVIMConversationCallback() {
        @Override
        public void done(AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            // TODO: modify return data.
            Map<String, Object> operationResult = new HashMap<>();
            operationResult.put("update", conversation.getUpdatedAt());
            result.success(Common.wrapSuccessResponse(operationResult));
          }
        }
      };
      if (Common.Conv_Operation_Mute.equalsIgnoreCase(operation)) {
        conversation.mute(callback);
      } else if (Common.Conv_Operation_Unmute.equalsIgnoreCase(operation)) {
        conversation.unmute(callback);
      } else {
        result.notImplemented();
      }
    } else if (call.method.equals(Common.Method_Update_Conversation)) {
      Map<String, Object> updateData = Common.getMethodParam(call, Common.Param_Conv_Data);
      if (null == updateData || updateData.isEmpty()) {
        result.success(Common.wrapException(AVException.INVALID_PARAMETER, "update attributes is empty."));
      } else {
        for (Map.Entry<String, Object> entry: updateData.entrySet()) {
          String key = entry.getKey();
          Object val = entry.getValue();
          conversation.setAttribute(key, val);
        }
        conversation.updateInfoInBackground(new AVIMConversationCallback() {
          @Override
          public void done(AVIMException e) {
            if (null != e) {
              result.success(Common.wrapException(e));
            } else {
              result.success(Common.wrapSuccessResponse(Common.wrapConversation(conversation)));
            }
          }
        });
      }
    } else if (call.method.equals(Common.Method_Update_Members)) {
      String operation = Common.getMethodParam(call, Common.Param_Conv_Operation);
      List<String> members = Common.getMethodParam(call, Common.Param_Conv_Members);
      AVIMConversationCallback callback = new AVIMConversationCallback() {
        @Override
        public void done(AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            result.success(Common.wrapSuccessResponse(Common.wrapConversation(conversation)));
          }
        }
      };
      if (null == members || members.isEmpty()) {
        result.success(Common.wrapException(AVException.INVALID_PARAMETER, "member list is empty."));
      } else if (Common.Conv_Operation_Add.equalsIgnoreCase(operation)) {
        conversation.addMembers(members, callback);
      } else if (Common.Conv_Operation_Remove.equalsIgnoreCase(operation)) {
        conversation.kickMembers(members, callback);
      } else {
        result.notImplemented();
      }
    } else if (call.method.equals(Common.Method_Get_Message_Receipt)) {
      conversation.fetchReceiptTimestamps(new AVIMConversationCallback() {
        @Override
        public void done(AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> tsMap = new HashMap<>();
            tsMap.put("maxReadTimestamp", conversation.getLastReadAt());
            tsMap.put("maxDeliveredTimestamp", conversation.getLastDeliveredAt());
            result.success(Common.wrapSuccessResponse(tsMap));
          }
        }
      });
    } else if (call.method.equals(Common.Method_Query_Member_Count)) {
      conversation.getMemberCount(new AVIMConversationMemberCountCallback() {
        @Override
        public void done(Integer memberCount, AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            result.success(Common.wrapSuccessResponse(memberCount));
          }
        }
      });
    } else if (call.method.equals(Common.Method_Query_Message)) {
      Map<String, Object> startData = Common.getMethodParam(call, Common.Param_Query_Start);
      Map<String, Object> endData = Common.getMethodParam(call, Common.Param_Query_End);
      int direction = Common.getParamInt(call, Common.Param_Query_Direction);
      int limit = Common.getParamInt(call, Common.Param_Query_Limit);
      int type = Common.getParamInt(call, Common.Param_Query_MsgType);
      AVIMMessageIntervalBound start = Common.parseMessageIntervalBound(startData);
      AVIMMessageIntervalBound end = Common.parseMessageIntervalBound(endData);
      AVIMMessageInterval interval = new AVIMMessageInterval(start, end);
      AVIMMessagesQueryCallback callback = new AVIMMessagesQueryCallback() {
        @Override
        public void done(List<AVIMMessage> messages, AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            List<Map<String, Object>> opResult = new ArrayList<>();
            for (AVIMMessage msg: messages) {
              opResult.add(Common.wrapMessage(msg));
            }
            result.success(Common.wrapSuccessResponse(opResult));
          }
        }
      };
      if (0 == limit) {
        limit = 50;
      }

      if (0 != type) {
        // ignore direction and end.
        String messageId = null;
        long startTimestamp = 0;
        if (null != start) {
          messageId = start.messageId;
          startTimestamp = start.timestamp;
        }
        conversation.queryMessagesByType(type, messageId, startTimestamp, limit, callback);
      } else {
        AVIMMessageQueryDirection direct = AVIMMessageQueryDirection.AVIMMessageQueryDirectionFromNewToOld;
        if (2 == direction) {
          direct = AVIMMessageQueryDirection.AVIMMessageQueryDirectionFromOldToNew;
        }
        conversation.queryMessages(interval, direct, limit, callback);
      }
    } else if (call.method.equals(Common.Method_Read_Message)) {
      conversation.read();
      result.success(Common.wrapSuccessResponse(new HashMap<String, Object>()));
    } else if (call.method.equals(Common.Method_Send_Message)) {
      Map<String, Object> msgData = Common.getMethodParam(call, Common.Param_Message_Raw);
      Map<String, Object> optionData = Common.getMethodParam(call, Common.Param_Message_Options);
      final AVIMMessage message = Common.parseMessage(msgData);
      AVIMMessageOption option = Common.parseMessageOption(optionData);
      Log.d(TAG, "send message from conv:" + message.getConversationId());
      conversation.sendMessage(message, option,
          new AVIMConversationCallback() {
            @Override
            public void done(AVIMException e) {
              if (null != e) {
                Log.d(TAG, "send failed. cause: " + e.getMessage());
                result.success(Common.wrapException(e));
              } else {
                Log.d(TAG, "send finished. message: " + message);
                result.success(Common.wrapSuccessResponse(Common.wrapMessage(message)));
              }
            }
          });
    } else if (call.method.equals(Common.Method_Update_Message)) {
      // TODO: support additional file data.
      Map<String, Object> oldMsgData = Common.getMethodParam(call, Common.Param_Message_Old);
      Map<String, Object> newMsgData = Common.getMethodParam(call, Common.Param_Message_New);
      AVIMMessage oldMessage = Common.parseMessage(oldMsgData);
      AVIMMessage newMessage = Common.parseMessage(newMsgData);
      conversation.updateMessage(oldMessage, newMessage, new AVIMMessageUpdatedCallback() {
            @Override
            public void done(AVIMMessage message, AVException e) {
              if (null != e) {
                result.success(Common.wrapException(e));
              } else {
                result.success(Common.wrapSuccessResponse(Common.wrapMessage(message)));
              }
            }
          });
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
  }

  public void notify(String method, Object param) {
    _CHANNEL.invokeMethod(method, param);
  }

  public void notifyWithResult(String method, Object param, Result callback) {
    _CHANNEL.invokeMethod(method, param, callback);
  }

  /**
   * ClientStatusListener#onDisconnected
   * @param client client instance.
   */
  public void onDisconnected(AVIMClient client) {
    _CHANNEL.invokeMethod(Common.Method_Client_Disconnected, Common.wrapClient(client));
  }

  /**
   * ClientStatusListener#onResumed
   * @param client client instance.
   */
  public void onResumed(AVIMClient client) {
    _CHANNEL.invokeMethod(Common.Method_Client_Resumed, Common.wrapClient(client));
  }

  /**
   * ClientStatusListener#onOffline
   * @param client client instance.
   * @param code detail code.
   */
  public void onOffline(AVIMClient client, int code) {
    Map<String, Object> param = Common.wrapClient(client);
    param.put(Common.Param_code, code);
    _CHANNEL.invokeMethod(Common.Method_Client_Offline, param);
  }
}
