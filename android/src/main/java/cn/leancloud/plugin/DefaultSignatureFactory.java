package cn.leancloud.plugin;

import java.util.List;

import cn.leancloud.im.Signature;
import cn.leancloud.im.SignatureFactory;

public class DefaultSignatureFactory implements SignatureFactory {
  public Signature createSignature(String peerId, List<String> watchIds) throws SignatureException {
    return null;
  }

  public Signature createConversationSignature(String conversationId, String clientId,
                                               List<String> targetIds, String action) throws SignatureException {
    return null;
  }

  public Signature createBlacklistSignature(String clientId, String conversationId, List<String> memberIds,
                                            String action) throws SignatureException {
    return null;
  }
}
