package cn.leancloud.plugin;

import android.util.Log;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import androidx.annotation.NonNull;
import cn.leancloud.AVException;
import cn.leancloud.AVFile;
import cn.leancloud.im.AVIMOptions;
import cn.leancloud.im.Signature;
import cn.leancloud.im.SignatureFactory;
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
import cn.leancloud.im.v2.callback.AVIMOperationFailure;
import cn.leancloud.im.v2.callback.AVIMOperationPartiallySucceededCallback;
import cn.leancloud.im.v2.messages.AVIMFileMessage;
import cn.leancloud.utils.StringUtil;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.common.StandardMethodCodec;

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
      _CHANNEL = new MethodChannel(messenger, "leancloud_plugin", new StandardMethodCodec(new LeanCloudMessageCodec()));
      _CHANNEL.setMethodCallHandler(_INSTANCE);

      AVIMMessageManager.registerDefaultMessageHandler(new DefaultMessageHandler(_INSTANCE));
      AVIMMessageManager.setConversationEventHandler(new DefaultConversationEventHandler(_INSTANCE));
      AVIMClient.setClientEventHandler(new DefaultClientEventHandler(_INSTANCE));
      AVIMOptions.getGlobalOptions().setSignatureFactory(DefaultSignatureFactory.getInstance());
    }
  }

  private SignatureFactory generateSignatureFactory() {
    return new SignatureFactory() {
      private void fillResult2Signature(Object result, Signature signature) {
        if (null != result && (result instanceof Map) && (((Map) result).containsKey("sign"))) {
          Object signData = ((Map)result).get("sign");
          if (null != signData && signData instanceof Map) {
            Map<String, Object> signMap = (Map<String, Object>)signData;
            String signatureString = (String) signMap.get("s");
            int timestamp = (int) signMap.get("t");
            String nounce = (String) signMap.get("n");
            signature.setSignature(signatureString);
            signature.setTimestamp(timestamp);
            signature.setNonce(nounce);
          }
        }
      }

      @Override
      public Signature createSignature(String peerId, List<String> watchIds) throws SignatureException {
        Map<String, Object> params = new HashMap<>();
        params.put(Common.Param_Client_Id, peerId);
        final Signature signature = new Signature();
        final CountDownLatch latch = new CountDownLatch(1);
        _CHANNEL.invokeMethod(Common.Method_Sign_SessionOpen, params, new Result() {
          @Override
          public void success(Object result) {
            fillResult2Signature(result, signature);
            latch.countDown();
          }

          @Override
          public void error(String errorCode, String errorMessage, Object errorDetails) {
            Log.w(TAG, "failed to invoke session open signature. code=" + errorCode + ", message=" + errorMessage);
            latch.countDown();
          }

          @Override
          public void notImplemented() {
            Log.w(TAG, "Session open signature not implemented.");
            latch.countDown();
          }
        });
        try {
          latch.await(30, TimeUnit.SECONDS);
        } catch (InterruptedException ex) {

        }
        return signature;
      }

      @Override
      public Signature createConversationSignature(String conversationId, String clientId,
                                                   List<String> targetIds, String action) throws SignatureException {
        Map<String, Object> params = new HashMap<>();
        params.put(Common.Param_Client_Id, clientId);
        params.put(Common.Param_Conv_Id, conversationId);
        params.put(Common.Param_Sign_TargetIds, targetIds);
        params.put(Common.Param_Sign_Action, action);
        final Signature signature = new Signature();
        final CountDownLatch latch = new CountDownLatch(1);
        _CHANNEL.invokeMethod(Common.Method_Sign_Conversation, params, new Result() {
          @Override
          public void success(Object result) {
            fillResult2Signature(result, signature);
            latch.countDown();
          }

          @Override
          public void error(String errorCode, String errorMessage, Object errorDetails) {
            Log.w(TAG, "failed to invoke conversation signature. code=" + errorCode + ", message=" + errorMessage);
            latch.countDown();
          }

          @Override
          public void notImplemented() {
            Log.w(TAG, "Conversation signature not implemented.");
            latch.countDown();
          }
        });
        try {
          latch.await(30, TimeUnit.SECONDS);
        } catch (InterruptedException ex) {
        }
        return signature;
      }

      @Override
      public Signature createBlacklistSignature(String clientId, String conversationId,
                                                List<String> memberIds, String action) throws SignatureException {
        return null;
      }
    };
  }

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
      Map<String, Boolean> signatureParam = Common.getMethodParam(call, Common.Param_Signature);
      boolean sessionSignFlag = false;
      boolean conversationSignFlag = false;
      if (null != signatureParam) {
        if (signatureParam.containsKey(Common.Param_Sign_SessionOpen)) {
          sessionSignFlag = signatureParam.get(Common.Param_Sign_SessionOpen);
        }
        if (signatureParam.containsKey(Common.Param_Sign_Conversation)) {
          conversationSignFlag = signatureParam.get(Common.Param_Sign_Conversation);
        }
      }
      SignatureFactory signatureFactory = null;
      if (sessionSignFlag || conversationSignFlag) {
        signatureFactory = generateSignatureFactory();
      }
      DefaultSignatureFactory.getInstance().registerSignedClient(clientId, sessionSignFlag,
          conversationSignFlag, signatureFactory);

      AVIMClientOpenOption openOption = new AVIMClientOpenOption();
      if (reconnectFlag) {
        openOption.setReconnect(true);
      }
      AVIMClient client = StringUtil.isEmpty(tag) ?
          AVIMClient.getInstance(clientId) : AVIMClient.getInstance(clientId, tag);
      client.open(openOption, new AVIMClientCallback() {
        @Override
        public void done(AVIMClient client, AVIMException e) {
          Log.d(TAG, "client open result: " + Common.wrapClient(client));
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
      final int convType = Common.getParamInt(call, Common.Param_Conv_Type);
      List<String> members = Common.getMethodParam(call, Common.Param_Conv_Members);
      String name = Common.getMethodParam(call, Common.Param_Conv_Name);
      Map<String, Object> attr = Common.getMethodParam(call, Common.Param_Conv_Attributes);
      final int ttl = Common.getParamInt(call, Common.Param_Conv_TTL);
      Log.d(TAG, "conv_type=" + convType + ", m=" + name + ", attr=" + attr + ", ttl=" + ttl);
      AVIMConversationCreatedCallback callback = new AVIMConversationCreatedCallback() {
        @Override
        public void done(AVIMConversation conversation, AVIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> convData = Common.wrapConversation(conversation);
            // we need to change ttl bcz that native sdk set ttl as aboslute timestamp(createdAt + ttl).
            if (ttl > 0 && convType == Common.Conv_Type_Temporary) {
              convData.put("ttl", ttl);
            }
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
          avimClient.createConversation(members, name, attr, false, false, callback);
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
      AVIMOperationPartiallySucceededCallback callback = new AVIMOperationPartiallySucceededCallback() {
        @Override
        public void done(AVIMException e, List<String> successfulClientIds, List<AVIMOperationFailure> failures) {
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
      Map<String, Object> fileData = Common.getMethodParam(call, Common.Param_Message_File);
      Log.d(TAG, "send message from conv:" + conversationId
          + ", message:" + JSON.toJSONString(msgData)
          + ", option:" + JSON.toJSONString(optionData));
      final AVIMMessage message = Common.parseMessage(msgData);
      if (message instanceof AVIMFileMessage && null != fileData) {
        byte[] byteArray = null;
        if (fileData.containsKey(Common.Param_File_Data)) {
          byteArray = (byte[]) fileData.get(Common.Param_File_Data);
        }
        String localPath = null;
        if (fileData.containsKey(Common.Param_File_Path)) {
          localPath = (String) fileData.get(Common.Param_File_Path);
        }
        String url = null;
        if (fileData.containsKey(Common.Param_File_Url)) {
          url = (String) fileData.get(Common.Param_File_Url);
        }
        String format = null;
        if (fileData.containsKey(Common.Param_File_Format)) {
          format = (String) fileData.get(Common.Param_File_Format);
        }
        String name = null;
        if (fileData.containsKey(Common.Param_File_Name)) {
          name = (String) fileData.get(Common.Param_File_Name);
        }
        if (StringUtil.isEmpty(name)) {
          name = StringUtil.getRandomString(16);
        }
        AVFile avFile = null;
        if (null != byteArray) {
          avFile = new AVFile(name, byteArray);
        } else if (!StringUtil.isEmpty(localPath)) {
          avFile = new AVFile(name, new File(localPath));
        } else if (!StringUtil.isEmpty(url)) {
          avFile = new AVFile(name, url);
        }
        if (null != avFile) {
          ((AVIMFileMessage) message).attachAVFile(avFile);
          if (!StringUtil.isEmpty(format)) {
            Map<String, Object> metaData = ((AVIMFileMessage)message).getFileMetaData();
            if (null != metaData) {
              metaData.put("format", format);
            }
          }
        } else {
          Log.d(TAG, "invalid file param!!");
        }
      }
      AVIMMessageOption option = Common.parseMessageOption(optionData);
      conversation.sendMessage(message, option,
          new AVIMConversationCallback() {
            @Override
            public void done(AVIMException e) {
              if (null != e) {
                Log.d(TAG, "send failed. cause: " + e.getMessage());
                result.success(Common.wrapException(e));
              } else {
                Log.d(TAG, "send finished. message: " + Common.wrapMessage(message));
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
//    } else if (call.method.equals(Common.Method_Conv_Update_Status)) {
//      boolean unreadMention = Common.getParamBoolean(call, Common.Param_Unread_Mention);
//      conversation.unreadMessagesMentioned();
//      result.success(Common.wrapSuccessResponse(0));
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
  }

  public void notify(String method, Object param) {
    Log.d(TAG, "notify mehtod=" + method + ", param=" + JSON.toJSONString(param));
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
    Map<String, Object> error = new HashMap<>();
    error.put(Common.Param_Code, code);
    param.put(Common.Param_Error, error);
    _CHANNEL.invokeMethod(Common.Method_Client_Offline, param);
  }
}
