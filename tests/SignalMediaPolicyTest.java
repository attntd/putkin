import java.lang.reflect.InvocationTargetException;
import java.util.Collections;
import java.util.Optional;
import org.asamk.signal.manager.api.ReceiveConfig;
import org.asamk.signal.manager.helper.IncomingMessageHandler;
import org.asamk.signal.manager.helper.PutkinMediaPolicy;
import org.asamk.signal.manager.storage.AttachmentStore;
import org.whispersystems.signalservice.api.messages.SignalServiceDataMessage;

/** Executes the patched receive method with a tripwire instead of a downloader. */
public class SignalMediaPolicyTest {
    public static void main(String[] args) throws Exception {
        PutkinMediaPolicy.main(args);
        var field = sun.misc.Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        var unsafe = (sun.misc.Unsafe) field.get(null);
        // Deliberately absent context: any attempt to reach a downloader fails.
        var handler = (IncomingMessageHandler) unsafe.allocateInstance(IncomingMessageHandler.class);
        var method = java.util.Arrays.stream(IncomingMessageHandler.class.getDeclaredMethods())
            .filter(m -> m.getName().equals("handleSignalServiceDataMessage")).findFirst().orElseThrow();
        method.setAccessible(true);
        int skipped = 0, reached = 0;
        for (boolean sync : new boolean[] {false, true}) {
            for (boolean ignore : new boolean[] {false, true}) {
                for (int kind : new int[] {0, 1, 2}) {
                    var data = SignalServiceDataMessage.newBuilder().withTimestamp(1)
                        .withAttachments(Collections.singletonList(null))
                        .withViewOnce(kind == 1).withExpiration(kind == 2 ? 60 : 0).build();
                    try {
                        method.invoke(handler, data, sync, null, null, new ReceiveConfig(ignore, true, true, true, false));
                        if (kind != 1) throw new AssertionError("ordinary media was skipped");
                        skipped++;
                    } catch (InvocationTargetException error) {
                        if (kind == 1 || !(error.getCause() instanceof NullPointerException)) throw error;
                        reached++;
                    }
                }
            }
        }
        var extension = AttachmentStore.class.getDeclaredMethod("getAttachmentExtension", Optional.class, Optional.class);
        extension.setAccessible(true);
        if (!".png".equals(extension.invoke(null, Optional.of("evil.sh/../../outside"), Optional.of("image/png")))) throw new AssertionError();
        if (skipped != 4 || reached != 8) throw new AssertionError();
        System.out.println("PASS: actual receive method skips view-once for incoming and sent sync, with both ignore settings; ordinary/expiring media reach downloader; hostile filename cannot choose extension");
    }
}
