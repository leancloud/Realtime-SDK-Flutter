package cn.leancloud.plugin;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.nio.charset.Charset;

import cn.leancloud.utils.LCUtils;
import io.flutter.plugin.common.StandardMessageCodec;

public class LeanCloudMessageCodec extends StandardMessageCodec {
  private static final Charset UTF8 = Charset.forName("UTF8");
  private static final byte INT = 3;
  private static final byte LONG = 4;
  private static final byte BIGINT = 5;
  private static final byte DOUBLE = 6;

  @Override
  protected void writeValue(ByteArrayOutputStream stream, Object value) {
    if (value instanceof Number) {
      if (value instanceof Integer || value instanceof Short || value instanceof Byte) {
        stream.write(INT);
        writeInt(stream, ((Number) value).intValue());
      } else if (value instanceof Long) {
        stream.write(LONG);
        writeLong(stream, (long) value);
      } else if (value instanceof Float || value instanceof Double) {
        stream.write(DOUBLE);
        writeAlignment(stream, 8);
        writeDouble(stream, ((Number) value).doubleValue());
      } else if (value instanceof BigInteger) {
        stream.write(BIGINT);
        writeBytes(stream,
            ((BigInteger) value).toString(16).getBytes(UTF8));
      } else if (value instanceof BigDecimal){
        stream.write(DOUBLE);
        writeAlignment(stream, 8);
        double newValue = LCUtils.normalize2Double(2, (BigDecimal) value);
        writeDouble(stream, newValue);
      } else {
        throw new IllegalArgumentException("Unsupported Number type: " + value.getClass());
      }
    } else {
      super.writeValue(stream, value);
    }
  }
}
