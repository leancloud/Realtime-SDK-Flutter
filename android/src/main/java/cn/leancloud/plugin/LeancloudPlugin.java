package cn.leancloud.plugin;

import android.util.Log;

import java.util.List;
import java.util.Map;

import androidx.annotation.NonNull;
import cn.leancloud.im.Signature;
import cn.leancloud.im.v2.AVIMClient;
import cn.leancloud.im.v2.AVIMClientOpenOption;
import cn.leancloud.im.v2.AVIMConversation;
import cn.leancloud.im.v2.AVIMException;
import cn.leancloud.im.v2.AVIMMessageManager;
import cn.leancloud.im.v2.callback.AVIMClientCallback;
import cn.leancloud.im.v2.callback.AVIMConversationCreatedCallback;
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
//    final MethodChannel channel = new MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "leancloud_plugin");
//    channel.setMethodCallHandler(this);
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
//    final MethodChannel channel = new MethodChannel(registrar.messenger(), "leancloud_plugin");
//    channel.setMethodCallHandler(_INSTANCE);
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

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull final Result result) {
    Log.d(TAG, "onMethodCall " + call.method);

    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
      return;
    }

    String clientId = Common.getMethodParam(call, Common.Param_Client_Id);
    if (StringUtil.isEmpty(clientId)) {
      result.error(Exception.ErrorCode_Invalid_Login, Exception.ErrorMsg_Invalid_Login, clientId);
      return;
    }

    if (call.method.equals(Common.Method_Open_Client)) {
      String tag = Common.getMethodParam(call, Common.Param_Client_Tag);
      boolean forceFlag = Common.getParamBoolean(call, Common.Param_Force_Open);
//      Signature signature = Common.getMethodSignature(call, Common.Param_Signature);
      AVIMClientOpenOption openOption = new AVIMClientOpenOption();
      if (forceFlag) {
        openOption.setReconnect(false);
      }
      AVIMClient client = StringUtil.isEmpty(tag)?
          AVIMClient.getInstance(clientId) : AVIMClient.getInstance(clientId, tag);
      client.open(openOption, new AVIMClientCallback() {
        @Override
        public void done(AVIMClient client, AVIMException e) {
          Log.d(TAG, "client open result: " + client);
          if (null != e) {
            result.error(String.valueOf(e.getCode()), e.getMessage(), e.getCause());
          } else {
            result.success(Common.wrapClient(client));
          }
        }
      });
      return;
    }

    AVIMClient avimClient = AVIMClient.getInstance(clientId);
    if (call.method.equals(Common.Method_Close_Client)){
      avimClient.close(new AVIMClientCallback() {
        @Override
        public void done(AVIMClient client, AVIMException e) {
          if (null != e) {
            result.error(String.valueOf(e.getCode()), e.getMessage(), e.getCause());
          } else {
            result.success(Common.wrapClient(client));
          }
        }
      });
    } else if (call.method.equals(Common.Method_Create_Conversation)) {
      int convType = Common.getParamInt(call, Common.Param_Conv_Type);
      List<String> members = Common.getMethodParam(call, Common.Param_Conv_Members);
      String name = Common.getMethodParam(call, Common.Param_Conv_Name);
      Map<String, Object> attr = Common.getMethodParam(call, Common.Param_Conv_Attributes);
      int ttl = Common.getParamInt(call, Common.Param_Conv_TTL);
      AVIMConversationCreatedCallback callback = new AVIMConversationCreatedCallback() {
        @Override
        public void done(AVIMConversation conversation, AVIMException e) {
          if (null != e) {
            result.error(String.valueOf(e.getAppCode()), e.getMessage(), e.getCause());
          } else {
            result.success(Common.wrapConversation(conversation));
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
    } else if (call.method.equals(Common.Method_Fetch_Conversation)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Mute_Conversation)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Update_Conversation)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Update_Members)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Get_Message_Receipt)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Online_Member_Count)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Query_Message)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Read_Message)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Send_Message)) {
      result.notImplemented();
    } else if (call.method.equals(Common.Method_Update_Message)) {
      result.notImplemented();
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
