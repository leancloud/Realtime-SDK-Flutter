package cn.leancloud.plugin;

import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

import cn.leancloud.im.Signature;
import cn.leancloud.im.SignatureFactory;

public class DefaultSignatureFactory implements SignatureFactory {
  private static final DefaultSignatureFactory _instance = new DefaultSignatureFactory();
  public static DefaultSignatureFactory getInstance() {
    return _instance;
  }

  private ConcurrentHashMap<String, SignatureFactory> sessionSignSettings = new ConcurrentHashMap<>();
  private ConcurrentHashMap<String, SignatureFactory> conversationSignSettings = new ConcurrentHashMap<>();
  private DefaultSignatureFactory() {
    ;
  }

  public void registerSignedClient(String clientId, boolean enableSessionSign,
                                   boolean enableConversationSign, SignatureFactory signatureFactory) {
    if (enableSessionSign && null != signatureFactory) {
      sessionSignSettings.put(clientId, signatureFactory);
    } else {
      sessionSignSettings.remove(clientId);
    }

    if (enableConversationSign && null != signatureFactory) {
      conversationSignSettings.put(clientId, signatureFactory);
    } else {
      conversationSignSettings.remove(clientId);
    }
  }

  public Signature createSignature(String peerId, List<String> watchIds) throws SignatureException {
    if (sessionSignSettings.containsKey(peerId)) {
      return sessionSignSettings.get(peerId).createSignature(peerId, watchIds);
    }
    return null;
  }

  public Signature createConversationSignature(String conversationId, String clientId,
                                               List<String> targetIds, String action) throws SignatureException {
    if (conversationSignSettings.containsKey(clientId)) {
      return conversationSignSettings.get(clientId).createConversationSignature(conversationId, clientId, targetIds, action);
    }
    return null;
  }

  public Signature createBlacklistSignature(String clientId, String conversationId, List<String> memberIds,
                                            String action) throws SignatureException {
    return null;
  }
}
