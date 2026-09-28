import com.fasterxml.jackson.databind.ObjectMapper;
import org.asamk.signal.manager.helper.CallManager;
import org.asamk.signal.manager.storage.SignalAccount;

/** Run the actual CLI-to-tunnel serializer, without creating an account or tunnel. */
class SignalCallContractTest {
    public static void main(String[] args) throws Exception {
        var field = sun.misc.Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        var unsafe = (sun.misc.Unsafe) field.get(null);
        var account = (SignalAccount) unsafe.allocateInstance(SignalAccount.class);
        var manager = (CallManager) unsafe.allocateInstance(CallManager.class);
        var accountField = CallManager.class.getDeclaredField("account");
        accountField.setAccessible(true);
        accountField.set(manager, account);
        var device = SignalAccount.class.getDeclaredField("deviceId");
        device.setAccessible(true);
        var stateType = Class.forName("org.asamk.signal.manager.helper.CallManager$CallState");
        var state = unsafe.allocateInstance(stateType);
        var callId = stateType.getDeclaredField("callId");
        callId.setAccessible(true);
        callId.setLong(state, Long.MIN_VALUE + 1);
        var config = CallManager.class.getDeclaredMethod("buildConfig", stateType);
        config.setAccessible(true);
        for (int id : new int[]{1, 2, 7}) {
            device.setInt(account, id);
            var json = new ObjectMapper().readTree((String) config.invoke(manager, state));
            if (json.get("local_device_id").asInt() != id)
                throw new AssertionError("Tunnel received the wrong local device");
            if (!json.get("call_id").asText().equals("9223372036854775809"))
                throw new AssertionError("Unsigned tunnel call ID was truncated");
        }
        System.out.println("PASS: tunnel receives actual linked device IDs and lossless unsigned call ID");
    }
}
