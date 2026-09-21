import java.util.Optional;

/** Actual pinned CLI types; synthetic records, no account, network or UI. */
class SignalEventContractTest {
    public static void main(String[] args) throws Exception {
        var type = Class.forName("org.asamk.signal.manager.api.MessageEnvelope$Typing$Type");
        var record = Class.forName("org.asamk.signal.manager.api.MessageEnvelope$Typing");
        var json = Class.forName("org.asamk.signal.json.JsonTypingMessage");
        var from = json.getDeclaredMethod("from", record);
        var action = json.getDeclaredMethod("action");
        from.setAccessible(true);
        action.setAccessible(true);
        var states = type.getEnumConstants();
        if (states.length != 2) throw new AssertionError("Typing enum changed");
        var expected = new String[]{"STARTED", "STOPPED"};
        for (int i = 0; i < states.length; i++) {
            var value = record.getDeclaredConstructor(long.class, type, Optional.class)
                .newInstance(1790000000000L, states[i], Optional.empty());
            if (!expected[i].equals(action.invoke(from.invoke(null, value))))
                throw new AssertionError("Typing wire action changed");
        }
        System.out.println("PASS: pinned CLI serializes typing as STARTED/STOPPED");
    }
}
