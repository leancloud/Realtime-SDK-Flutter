package cn.leancloud.plugin;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import cn.leancloud.im.v2.callback.LCIMConversationIterableResult;
import cn.leancloud.im.v2.callback.LCIMConversationIterableResultCallback;
import cn.leancloud.json.JSON;
import cn.leancloud.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import androidx.annotation.NonNull;

import cn.leancloud.LCException;
import cn.leancloud.LCFile;
import cn.leancloud.im.LCIMOptions;
import cn.leancloud.im.Signature;
import cn.leancloud.im.SignatureFactory;
import cn.leancloud.im.v2.LCIMClient;
import cn.leancloud.im.v2.LCIMClientOpenOption;
import cn.leancloud.im.v2.LCIMConversation;
import cn.leancloud.im.v2.LCIMConversationsQuery;
import cn.leancloud.im.v2.LCIMException;
import cn.leancloud.im.v2.LCIMMessage;
import cn.leancloud.im.v2.LCIMMessageInterval;
import cn.leancloud.im.v2.LCIMMessageInterval.MessageIntervalBound;
import cn.leancloud.im.v2.LCIMMessageManager;
import cn.leancloud.im.v2.LCIMMessageOption;
import cn.leancloud.im.v2.LCIMMessageQueryDirection;
import cn.leancloud.im.v2.callback.LCIMClientCallback;
import cn.leancloud.im.v2.callback.LCIMConversationCallback;
import cn.leancloud.im.v2.callback.LCIMConversationCreatedCallback;
import cn.leancloud.im.v2.callback.LCIMConversationMemberCountCallback;
import cn.leancloud.im.v2.callback.LCIMConversationQueryCallback;
import cn.leancloud.im.v2.callback.LCIMMessageRecalledCallback;
import cn.leancloud.im.v2.callback.LCIMMessageUpdatedCallback;
import cn.leancloud.im.v2.callback.LCIMMessagesQueryCallback;
import cn.leancloud.im.v2.callback.LCIMOperationFailure;
import cn.leancloud.im.v2.callback.LCIMOperationPartiallySucceededCallback;
import cn.leancloud.im.v2.messages.LCIMFileMessage;
import cn.leancloud.im.v2.messages.LCIMRecalledMessage;
import cn.leancloud.utils.StringUtil;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.plugin.common.StandardMethodCodec;

/**
 * LeancloudPlugin
 */
public class LeancloudPlugin implements FlutterPlugin, MethodCallHandler,
        ClientStatusListener, IMEventNotification {
  private final static String TAG = LeancloudPlugin.class.getSimpleName();
  private final static LeancloudPlugin _INSTANCE = new LeancloudPlugin();
  private static MethodChannel _CHANNEL = null;
  private static Handler handler;

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
//    if (null == _CHANNEL) {
    _CHANNEL = new MethodChannel(messenger, "leancloud_plugin", new StandardMethodCodec(new LeanCloudMessageCodec()));
    _CHANNEL.setMethodCallHandler(_INSTANCE);

    LCIMMessageManager.registerDefaultMessageHandler(new DefaultMessageHandler(_INSTANCE));
    LCIMMessageManager.setConversationEventHandler(new DefaultConversationEventHandler(_INSTANCE));
    LCIMClient.setClientEventHandler(new DefaultClientEventHandler(_INSTANCE));
    LCIMOptions.getGlobalOptions().setSignatureFactory(DefaultSignatureFactory.getInstance());
    handler = new Handler(Looper.getMainLooper());
//    }
  }

  private SignatureFactory generateSignatureFactory() {
    return new SignatureFactory() {
      private void fillResult2Signature(Object result, Signature signature) {
        if (null != result && (result instanceof Map) && (((Map) result).containsKey("sign"))) {
          Object signData = ((Map) result).get("sign");
          if (null != signData && signData instanceof Map) {
            Map<String, Object> signMap = (Map<String, Object>) signData;
            String signatureString = (String) signMap.get("s");
            long timestamp = (long) signMap.get("t");
            String nounce = (String) signMap.get("n");
            signature.setSignature(signatureString);
            signature.setTimestamp(timestamp);
            signature.setNonce(nounce);
          }
        }
      }

      @Override
      public Signature createSignature(String peerId, List<String> watchIds) throws SignatureException {
        final Map<String, Object> params = new HashMap<>();
        params.put(Common.Param_Client_Id, peerId);
        final Signature signature = new Signature();
        final CountDownLatch latch = new CountDownLatch(1);
        handler.post(new Runnable() {
          @Override
          public void run() {
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
        final Map<String, Object> params = new HashMap<>();
        params.put(Common.Param_Client_Id, clientId);
        if (!StringUtil.isEmpty(conversationId)) {
          params.put(Common.Param_Conv_Id, conversationId);
        }
        params.put(Common.Param_Sign_TargetIds, targetIds);
        params.put(Common.Param_Sign_Action, action);
        final Signature signature = new Signature();
        final CountDownLatch latch = new CountDownLatch(1);
        handler.post(new Runnable() {
          @Override
          public void run() {
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
          }
        });
        try {
          latch.await(30, TimeUnit.SECONDS);
        } catch (InterruptedException ex) {
          Log.w(TAG, "conversation sign timeout. cause: " + ex.getMessage());
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

  private boolean isDeleteOperation(Object value) {
    if (null != value && value instanceof Map) {
      Object operation = ((Map<String, Object>) value).get("__op");
      if (operation instanceof String) {
        return "Delete".equalsIgnoreCase((String) operation);
      }
    }
    return false;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull final Result result) {
    Log.d(TAG, "onMethodCall " + call.method + "， args:" + call.arguments);

    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
      return;
    }

    final String clientId = Common.getMethodParam(call, Common.Param_Client_Id);
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

      LCIMClientOpenOption openOption = new LCIMClientOpenOption();
      if (reconnectFlag) {
        openOption.setReconnect(true);
      }
      LCIMClient client = StringUtil.isEmpty(tag) ?
              LCIMClient.getInstance(clientId) : LCIMClient.getInstance(clientId, tag);
      client.open(openOption, new LCIMClientCallback() {
        @Override
        public void done(LCIMClient client, LCIMException e) {
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

    LCIMClient avimClient = LCIMClient.getInstance(clientId);

    if (call.method.equals(Common.Method_Close_Client)) {
      avimClient.close(new LCIMClientCallback() {
        @Override
        public void done(LCIMClient client, LCIMException e) {
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
      LCIMConversationCreatedCallback callback = new LCIMConversationCreatedCallback() {
        @Override
        public void done(LCIMConversation conversation, LCIMException e) {
          if (null != e) {
            Log.d(TAG, "failed to create conv. cause:" + e.getMessage());
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> convData = Common.wrapConversation(conversation);
            // we need to change ttl bcz that native sdk set ttl as aboslute timestamp(createdAt + ttl).
            if (ttl > 0 && convType == Common.Conv_Type_Temporary) {
              convData.put("ttl", ttl);
            }
            Log.d(TAG, "succeed create conv: " + JSON.toJSONString(convData));
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
      LCIMConversationQueryCallback callback = new LCIMConversationQueryCallback() {
        @Override
        public void done(List<LCIMConversation> conversations, LCIMException e) {
          if (null != e) {
            Log.d(TAG, "failed to query conv. cause:" + e.getMessage());
            result.success(Common.wrapException(e));
          } else {
            List<Map<String, Object>> queryResult = new ArrayList<>();
            for (LCIMConversation conv : conversations) {
              queryResult.add(Common.wrapConversation(conv));
            }
            result.success(Common.wrapSuccessResponse(queryResult));
          }
        }
      };
      LCIMConversationsQuery query = avimClient.getConversationsQuery();
      if (null == tempConvIds || tempConvIds.isEmpty()) {
        query.directFindInBackground(where, sort, skip, limit, flag, callback);
      } else {
        query.findTempConversationsInBackground(tempConvIds, callback);
      }
      return;
    }

    String conversationId = Common.getMethodParam(call, Common.Param_Conv_Id);
    final LCIMConversation conversation = avimClient.getConversation(conversationId);
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
      final String operation = Common.getMethodParam(call, Common.Param_Conv_Operation);
      LCIMConversationCallback callback = new LCIMConversationCallback() {
        @Override
        public void done(LCIMException e) {
          if (null != e) {
            Log.d(TAG, "failed to mute/unmute conversation. cause:" + e.getMessage());
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> operationResult = new HashMap<>();
            operationResult.put(Common.Param_Update_Time, StringUtil.stringFromDate(conversation.getUpdatedAt()));
            if (Common.Conv_Operation_Mute.equalsIgnoreCase(operation)) {
              operationResult.put("mu", Arrays.asList(clientId));
            } else if (Common.Conv_Operation_Unmute.equalsIgnoreCase(operation)) {
              operationResult.put("mu", new ArrayList<>());
            }
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
        result.success(Common.wrapException(LCException.INVALID_PARAMETER, "update attributes is empty."));
      } else {
        for (Map.Entry<String, Object> entry : updateData.entrySet()) {
          String key = entry.getKey();
          Object val = entry.getValue();
          if (isDeleteOperation(val)) {
            conversation.remove(key);
          } else {
            conversation.setAttribute(key, val);
          }
        }
        conversation.updateInfoInBackground(new LCIMConversationCallback() {
          @Override
          public void done(LCIMException e) {
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
      LCIMOperationPartiallySucceededCallback callback = new LCIMOperationPartiallySucceededCallback() {
        @Override
        public void done(LCIMException e, List<String> successfulClientIds, List<LCIMOperationFailure> failures) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> resultMap = new HashMap<>();
            resultMap.put("allowedPids", successfulClientIds);

            if (null != failures) {
              List<Map<String, Object>> failedList = new ArrayList<>();
              for (LCIMOperationFailure f : failures) {
                Map<String, Object> failedData = new HashMap<>();
                failedData.put("pids", f.getMemberIds());
                Map<String, String> errorMap = new HashMap<>();
                errorMap.put("code", String.valueOf(f.getCode()));
                errorMap.put("message", f.getReason());
                failedData.put(Common.Param_Error, errorMap);
                failedList.add(failedData);
              }
              resultMap.put("failedPids", failedList);
            }
            resultMap.put(Common.Param_Conv_Members, conversation.getMembers());
            resultMap.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
            result.success(Common.wrapSuccessResponse(resultMap));
          }
        }
      };
      if (null == members || members.isEmpty()) {
        result.success(Common.wrapException(LCException.INVALID_PARAMETER, "member list is empty."));
      } else if (Common.Conv_Operation_Add.equalsIgnoreCase(operation)) {
        conversation.addMembers(members, callback);
      } else if (Common.Conv_Operation_Remove.equalsIgnoreCase(operation)) {
        conversation.kickMembers(members, callback);
      } else {
        result.notImplemented();
      }
    } else if (call.method.equals(Common.Method_Update_Block_Members)) {
      String operation = Common.getMethodParam(call, Common.Param_Conv_Operation);
      List<String> members = Common.getMethodParam(call, Common.Param_Conv_Members);
      LCIMOperationPartiallySucceededCallback callback = new LCIMOperationPartiallySucceededCallback() {
        @Override
        public void done(LCIMException e, List<String> successfulClientIds, List<LCIMOperationFailure> failures) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> resultMap = new HashMap<>();
            resultMap.put("allowedPids", successfulClientIds);

            if (null != failures) {
              List<Map<String, Object>> failedList = new ArrayList<>();
              for (LCIMOperationFailure f : failures) {
                Map<String, Object> failedData = new HashMap<>();
                failedData.put("pids", f.getMemberIds());
                Map<String, String> errorMap = new HashMap<>();
                errorMap.put("code", String.valueOf(f.getCode()));
                errorMap.put("message", f.getReason());
                failedData.put(Common.Param_Error, errorMap);
                failedList.add(failedData);
              }
              resultMap.put("failedPids", failedList);
            }
            resultMap.put(Common.Param_Conv_Members, conversation.getMembers());
            resultMap.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
            result.success(Common.wrapSuccessResponse(resultMap));
          }
        }
      };
      if (null == members || members.isEmpty()) {
        result.success(Common.wrapException(LCException.INVALID_PARAMETER, "member list is empty."));
      } else if (Common.Conv_Operation_Block.equalsIgnoreCase(operation)) {
        conversation.blockMembers(members, callback);
      } else if (Common.Conv_Operation_Unblock.equalsIgnoreCase(operation)) {
        conversation.unblockMembers(members, callback);
      } else {
        result.notImplemented();
      }
    } else if (call.method.equals(Common.Method_Update_Mute_Members)) {
      String operation = Common.getMethodParam(call, Common.Param_Conv_Operation);
      List<String> members = Common.getMethodParam(call, Common.Param_Conv_Members);
      LCIMOperationPartiallySucceededCallback callback = new LCIMOperationPartiallySucceededCallback() {
        @Override
        public void done(LCIMException e, List<String> successfulClientIds, List<LCIMOperationFailure> failures) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> resultMap = new HashMap<>();
            resultMap.put("allowedPids", successfulClientIds);

            if (null != failures) {
              List<Map<String, Object>> failedList = new ArrayList<>();
              for (LCIMOperationFailure f : failures) {
                Map<String, Object> failedData = new HashMap<>();
                failedData.put("pids", f.getMemberIds());
                Map<String, String> errorMap = new HashMap<>();
                errorMap.put("code", String.valueOf(f.getCode()));
                errorMap.put("message", f.getReason());
                failedData.put(Common.Param_Error, errorMap);
                failedList.add(failedData);
              }
              resultMap.put("failedPids", failedList);
            }
            resultMap.put(Common.Param_Conv_Members, conversation.getMembers());
            resultMap.put(Common.Param_Update_Time, StringUtil.stringFromDate(new Date()));
            result.success(Common.wrapSuccessResponse(resultMap));
          }
        }
      };
      if (null == members || members.isEmpty()) {
        result.success(Common.wrapException(LCException.INVALID_PARAMETER, "member list is empty."));
      } else if (Common.Conv_Operation_Mute.equalsIgnoreCase(operation)) {
        conversation.muteMembers(members, callback);
      } else if (Common.Conv_Operation_Unmute.equalsIgnoreCase(operation)) {
        conversation.unmuteMembers(members, callback);
      } else {
        result.notImplemented();
      }
    } else if (call.method.equals(Common.Method_Query_Block_Members)) {
      int limit = Common.getParamInt(call, Common.Param_Query_Limit);
      String next = Common.getParamString(call, Common.Param_Query_Next);
      LCIMConversationIterableResultCallback callback = new LCIMConversationIterableResultCallback() {
        @Override
        public void done(LCIMConversationIterableResult iterableResult, LCIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> resultMap = new HashMap<>();
            resultMap.put("client_ids", iterableResult.getMembers());
            resultMap.put("next", iterableResult.getNext());
            result.success(Common.wrapSuccessResponse(resultMap));
          }
        }
      };
      if (0 == limit) {
        limit = 50;
      }
      conversation.queryBlockedMembers(limit, next, callback);
    } else if (call.method.equals(Common.Method_Query_Mute_Members)) {
      int limit = Common.getParamInt(call, Common.Param_Query_Limit);
      String next = Common.getParamString(call, Common.Param_Query_Next);
      LCIMConversationIterableResultCallback callback = new LCIMConversationIterableResultCallback() {
        @Override
        public void done(LCIMConversationIterableResult iterableResult, LCIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            Map<String, Object> resultMap = new HashMap<>();
            resultMap.put("client_ids", iterableResult.getMembers());
            resultMap.put("next", iterableResult.getNext());
            result.success(Common.wrapSuccessResponse(resultMap));
          }
        }
      };
      if (0 == limit) {
        limit = 50;
      }
      conversation.queryMutedMembers(limit, next, callback);
    } else if (call.method.equals(Common.Method_Get_Message_Receipt)) {
      conversation.fetchReceiptTimestamps(new LCIMConversationCallback() {
        @Override
        public void done(LCIMException e) {
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
      conversation.getMemberCount(new LCIMConversationMemberCountCallback() {
        @Override
        public void done(Integer memberCount, LCIMException e) {
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
      MessageIntervalBound start = Common.parseMessageIntervalBound(startData);
      MessageIntervalBound end = Common.parseMessageIntervalBound(endData);
      LCIMMessageInterval interval = new LCIMMessageInterval(start, end);
      LCIMMessagesQueryCallback callback = new LCIMMessagesQueryCallback() {
        @Override
        public void done(List<LCIMMessage> messages, LCIMException e) {
          if (null != e) {
            result.success(Common.wrapException(e));
          } else {
            List<Map<String, Object>> opResult = new ArrayList<>();
            for (LCIMMessage msg : messages) {
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
        LCIMMessageQueryDirection direct = LCIMMessageQueryDirection.DirectionFromNewToOld;
        if (2 == direction) {
          direct = LCIMMessageQueryDirection.DirectionFromOldToNew;
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
      final LCIMMessage message = Common.parseMessage(msgData);
      if (message instanceof LCIMFileMessage && null != fileData) {
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
        boolean keepFileName = false;
        if (fileData.containsKey(Common.Param_File_Name)) {
          name = (String) fileData.get(Common.Param_File_Name);
        }
        if (StringUtil.isEmpty(name)) {
          name = StringUtil.getRandomString(16);
        } else {
          keepFileName = true;
        }
        LCFile avFile = null;
        if (null != byteArray) {
          avFile = new LCFile(name, byteArray);
        } else if (!StringUtil.isEmpty(localPath)) {
          avFile = new LCFile(name, new File(localPath));
        } else if (!StringUtil.isEmpty(url)) {
          avFile = new LCFile(name, url);
        }
        if (null != avFile) {
          ((LCIMFileMessage) message).attachLCFile(avFile, keepFileName);
          if (!StringUtil.isEmpty(format)) {
            Map<String, Object> metaData = ((LCIMFileMessage) message).getFileMetaData();
            if (null != metaData) {
              metaData.put("format", format);
            }
          }
        } else {
          Log.d(TAG, "invalid file param!!");
        }
      }
      LCIMMessageOption option = Common.parseMessageOption(optionData);

      if (msgData.containsKey(Common.Param_Message_Transient)) {
        if (null == option) {
          option = new LCIMMessageOption();
        }
        try {
          boolean isTransient = (boolean) msgData.get(Common.Param_Message_Transient);
          option.setTransient(isTransient);
        } catch (java.lang.Exception ex) {
          Log.w(TAG, "invalid transient param. cause: " + ex.getMessage());
        }
      }
      conversation.sendMessage(message, option,
              new LCIMConversationCallback() {
                @Override
                public void done(LCIMException e) {
                  if (null != e) {
                    Log.d(TAG, "send failed. cause: " + e.getMessage());
                    result.success(Common.wrapException(e));
                  } else {
                    Log.d(TAG, "send finished. message: " + Common.wrapMessage(message));
                    result.success(Common.wrapSuccessResponse(Common.wrapMessage(message)));
                  }
                }
              });
    } else if (call.method.equals(Common.Method_Patch_Message)) {
      Map<String, Object> oldMsgData = Common.getMethodParam(call, Common.Param_Message_Old);
      Map<String, Object> newMsgData = Common.getMethodParam(call, Common.Param_Message_New);
      LCIMMessage oldMessage = Common.parseMessage(oldMsgData);
      LCIMMessage newMessage = Common.parseMessage(newMsgData);
      boolean isRecall = Common.getParamBoolean(call, Common.Param_Message_Recall);
      Map<String, Object> fileData = Common.getMethodParam(call, Common.Param_Message_File);
      if (newMessage instanceof LCIMFileMessage && null != fileData) {
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
        boolean keepFileName = false;
        if (fileData.containsKey(Common.Param_File_Name)) {
          name = (String) fileData.get(Common.Param_File_Name);
        }
        if (StringUtil.isEmpty(name)) {
          name = StringUtil.getRandomString(16);
        } else {
          keepFileName = true;
        }
        LCFile avFile = null;
        if (null != byteArray) {
          avFile = new LCFile(name, byteArray);
        } else if (!StringUtil.isEmpty(localPath)) {
          avFile = new LCFile(name, new File(localPath));
        } else if (!StringUtil.isEmpty(url)) {
          avFile = new LCFile(name, url);
        }
        if (null != avFile) {
          ((LCIMFileMessage) newMessage).attachLCFile(avFile, keepFileName);
          if (!StringUtil.isEmpty(format)) {
            Map<String, Object> metaData = ((LCIMFileMessage) newMessage).getFileMetaData();
            if (null != metaData) {
              metaData.put("format", format);
            }
          }
        } else {
          Log.d(TAG, "invalid file param!!");
        }
      }
      if (isRecall) {
        conversation.recallMessage(oldMessage, new LCIMMessageRecalledCallback() {
          @Override
          public void done(LCIMRecalledMessage recalledMessage, LCException e) {
            if (null != e) {
              result.success(Common.wrapException(e));
            } else {
              result.success(Common.wrapSuccessResponse(Common.wrapMessage(recalledMessage)));
            }
          }
        });
      } else {
        Log.d(TAG, "update message. old=" + oldMsgData + ", new=" + newMsgData);
        conversation.updateMessage(oldMessage, newMessage, new LCIMMessageUpdatedCallback() {
          @Override
          public void done(LCIMMessage message, LCException e) {
            if (null != e) {
              result.success(Common.wrapException(e));
            } else {
              result.success(Common.wrapSuccessResponse(Common.wrapMessage(message)));
            }
          }
        });
      }
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
    Log.d(TAG, "LeancloudPlugin.onDetachedFromEngine called.");
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
   *
   * @param client client instance.
   */
  public void onDisconnected(LCIMClient client) {
    _CHANNEL.invokeMethod(Common.Method_Client_Disconnected, Common.wrapClient(client));
  }

  /**
   * ClientStatusListener#onResumed
   *
   * @param client client instance.
   */
  public void onResumed(LCIMClient client) {
    _CHANNEL.invokeMethod(Common.Method_Client_Resumed, Common.wrapClient(client));
  }

  /**
   * ClientStatusListener#onOffline
   * @param client client instance.
   * @param code detail code.
   */
  public void onOffline(LCIMClient client, int code) {
    Map<String, Object> param = Common.wrapClient(client);
    Map<String, Object> error = new HashMap<>();
    error.put(Common.Param_Code, code);
    param.put(Common.Param_Error, error);
    _CHANNEL.invokeMethod(Common.Method_Client_Offline, param);
  }
}
