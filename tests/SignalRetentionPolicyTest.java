import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.File;
import java.util.Optional;
import java.util.Set;
import org.asamk.signal.manager.Manager;
import org.asamk.signal.manager.api.MessageEnvelope;
import org.asamk.signal.manager.storage.AccountDatabase;
import org.asamk.signal.manager.storage.sendLog.MessageSendLogStore;
import org.whispersystems.signalservice.api.crypto.ContentHint;
import org.whispersystems.signalservice.api.messages.SendMessageResult;

/** Real pinned serializer and SQLite resend store, isolated from account/network. */
public class SignalRetentionPolicyTest {
    public static void main(String[] args) throws Exception {
        var type = Class.forName("org.asamk.signal.json.JsonSyncDataMessage");
        var from = type.getDeclaredMethod("from", MessageEnvelope.Sync.Sent.class, Manager.class);
        from.setAccessible(true);
        var mapper = new ObjectMapper();
        for (long start : new long[] {0, 1790000000123L}) {
            var sent = new MessageEnvelope.Sync.Sent(1790000000000L, start,
                Optional.empty(), Set.of(), Optional.empty(), Optional.empty(), Optional.empty());
            var wire = mapper.readTree(mapper.writeValueAsBytes(from.invoke(null, sent, null)));
            if (!wire.has("expirationStartTimestamp") || wire.get("expirationStartTimestamp").asLong() != start) {
                throw new AssertionError("expiration start was lost during JSON serialization");
            }
        }
        org.asamk.signal.manager.helper.PutkinRetention.observe(1, 30);
        var actual = org.asamk.signal.manager.helper.PutkinRetention.result(1, java.util.List.of());
        if (!Integer.valueOf(30).equals(actual.get("expiresInSeconds"))) throw new AssertionError("actual send timer lost");
        if (org.asamk.signal.manager.helper.PutkinRetention.result(1, java.util.List.of()).containsKey("expiresInSeconds")) throw new AssertionError("timer not released");
        try (var database = AccountDatabase.init(new File("/tmp/retention-test.db"))) {
            try (var connection = database.getConnection(); var statement = connection.createStatement()) {
                statement.executeUpdate("INSERT INTO message_send_log_content(group_id,timestamp,content,content_hint,urgent) VALUES(NULL,1790000000000,X'50524956415445',0,0)");
            }
            try (var log = new MessageSendLogStore(database, true)) {
                if (log.insertIfPossible(1790000000000L, (SendMessageResult) null, ContentHint.RESENDABLE, true) != -1) {
                    throw new AssertionError("disabled send log accepted content");
                }
                try (var connection = database.getConnection(); var statement = connection.createStatement();
                        var rows = statement.executeQuery("SELECT COUNT(*) FROM message_send_log_content")) {
                    if (!rows.next() || rows.getLong(1) != 0) throw new AssertionError("old resend content survived");
                }
            }
        }
        System.out.println("PASS: real sent-sync JSON exports exact expiration start; disabled resend log removes legacy bodies and rejects new ones");
    }
}
