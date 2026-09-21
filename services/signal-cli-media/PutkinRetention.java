package org.asamk.signal.manager.helper;

import java.util.LinkedHashMap;
import java.util.Map;

/** Bounded metadata only: actual timer captured after the send builder is final. */
public final class PutkinRetention {
    private static final Map<Long, Integer> timers = new LinkedHashMap<>();
    private PutkinRetention() {}

    public static synchronized void observe(long timestamp, int seconds) {
        var old = timers.get(timestamp);
        // Putkin sends to one conversation. Multiple recipients with different
        // defaults in other CLI consumers conservatively use the shortest timer.
        timers.put(timestamp, old == null || old == 0 ? seconds : seconds == 0 ? old : Math.min(old, seconds));
        while (timers.size() > 1024) timers.remove(timers.keySet().iterator().next());
    }

    public static synchronized Map<String, Object> result(long timestamp, Object results) {
        var seconds = timers.remove(timestamp);
        return seconds == null ? Map.of("timestamp", timestamp, "results", results)
                : Map.of("timestamp", timestamp, "results", results, "expiresInSeconds", seconds);
    }
}
