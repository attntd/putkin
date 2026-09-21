package org.asamk.signal.manager.helper;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/** Local limits, not Signal protocol claims. No network access in this class. */
public final class PutkinMediaPolicy {
    public static final int FILE_LIMIT = 32 * 1024 * 1024;
    public static final int WIRE_LIMIT = 40 * 1024 * 1024;
    public static final long CACHE_LIMIT = 512L * 1024 * 1024;

    public static boolean allowed(long bytes) { return bytes > 0 && bytes <= FILE_LIMIT; }

    public static void checkSpace(Path directory) throws IOException {
        Files.createDirectories(directory);
        long used = 0;
        try (var paths = Files.list(directory)) {
            for (var path : paths.toList()) {
                if (Files.isSymbolicLink(path) || !Files.isRegularFile(path)) throw new IOException("Unsafe cache entry");
                used += Files.size(path);
                if (used + WIRE_LIMIT > CACHE_LIMIT) throw new IOException("Putkin cache limit");
            }
        }
        if (Files.getFileStore(directory).getUsableSpace() < 2L * WIRE_LIMIT) throw new IOException("Putkin disk reserve");
    }

    public static void main(String[] args) throws Exception {
        if (allowed(-1) || allowed(0) || allowed(FILE_LIMIT + 1L) || !allowed(FILE_LIMIT)) throw new AssertionError();
        Path cache = Files.createTempDirectory("putkin-media-policy-");
        try {
            checkSpace(cache);
            Path file = cache.resolve("large");
            try (var output = new java.io.RandomAccessFile(file.toFile(), "rw")) { output.setLength(CACHE_LIMIT); }
            boolean rejected = false;
            try { checkSpace(cache); } catch (IOException expected) { rejected = true; }
            if (!rejected) throw new AssertionError();
            Files.delete(file);
        } finally { Files.delete(cache); }
        System.out.println("PASS: size boundaries and real cache quota");
    }
}
