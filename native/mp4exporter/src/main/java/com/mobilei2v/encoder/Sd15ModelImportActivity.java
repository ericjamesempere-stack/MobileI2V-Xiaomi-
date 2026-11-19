package com.mobilei2v.encoder;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import org.json.JSONObject;
import java.io.*;
import java.util.*;
import java.util.zip.*;

/** User-selected SD1.5 model archive. No network, root, or storage permission. */
public final class Sd15ModelImportActivity extends Activity {
    private static final String[] REQUIRED = {"tokenizer.mtok", "text_encoder.mnn", "unet.mnn", "vae_decoder.mnn"};
    private static final String[] OPTIONAL_WEIGHTS = {"text_encoder.mnn.weight", "unet.mnn.weight", "vae_decoder.mnn.weight"};
    private static volatile String state = "{\"state\":\"idle\"}";
    private static volatile boolean busy;
    static synchronized boolean launch(Activity host) {
        if (host == null || busy) return false;
        busy = true;
        state = "{\"state\":\"selecting\"}";
        host.runOnUiThread(() -> host.startActivity(new Intent(host, Sd15ModelImportActivity.class)));
        return true;
    }
    static String status() { return state; }
    private static void report(String phase, long bytes) {
        try { state = new JSONObject().put("state", phase).put("bytes", bytes).toString(); }
        catch (Exception ignored) {}
    }
    @Override protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        if (saved != null) { busy = false; state = "{\"state\":\"error\",\"reason\":\"selection_interrupted\"}"; finish(); return; }
        Intent pick = new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        startActivityForResult(pick, 71);
    }
    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request != 71) return;
        if (result != RESULT_OK || data == null || data.getData() == null) {
            busy = false; state = "{\"state\":\"cancelled\"}"; finish(); return;
        }
        Uri uri = data.getData();
        report("importing", 0);
        new Thread(() -> {
            File base = new File(getFilesDir(), "models");
            File stage = new File(base, "sd15-import");
            File target = new File(base, "sd15");
            try {
                if (!base.isDirectory() && !base.mkdirs()) throw new IOException("models_directory");
                deleteTree(stage);
                if (!stage.mkdirs()) throw new IOException("stage_directory");
                Set<String> seen = new HashSet<>();
                long total = 0;
                byte[] buf = new byte[65536];
                try (InputStream input = getContentResolver().openInputStream(uri)) {
                    if (input == null) throw new IOException("document_unavailable");
                    try (ZipInputStream zip = new ZipInputStream(new BufferedInputStream(input))) {
                        ZipEntry entry;
                        while ((entry = zip.getNextEntry()) != null) {
                            if (entry.isDirectory()) { zip.closeEntry(); continue; }
                            String name = entry.getName().replace('\\', '/');
                            String leaf = name.substring(name.lastIndexOf('/') + 1);
                            if (!Arrays.asList(REQUIRED).contains(leaf) && !Arrays.asList(OPTIONAL_WEIGHTS).contains(leaf)) { zip.closeEntry(); continue; }
                            if (!seen.add(leaf)) throw new IOException("duplicate_model_file");
                            File out = new File(stage, leaf);
                            long fileBytes = 0;
                            try (OutputStream sink = new BufferedOutputStream(new FileOutputStream(out))) {
                                int n;
                                while ((n = zip.read(buf)) != -1) {
                                    total += n; fileBytes += n;
                                    if (total > 6_000_000_000L || fileBytes > 4_000_000_000L)
                                        throw new IOException("model_size_limit");
                                    sink.write(buf, 0, n);
                                    if ((total & ((1 << 23) - 1)) < n) report("importing", total);
                                }
                            }
                            if (fileBytes == 0) throw new IOException("empty_model_file");
                            zip.closeEntry();
                        }
                    }
                }
                for (String required : REQUIRED) if (!seen.contains(required)) throw new IOException("missing_model_files");
                // MNN can store large tensors in companion .weight files. Never install
                // a tiny graph without its external tensor file.
                for (String graph : new String[]{"text_encoder.mnn", "unet.mnn", "vae_decoder.mnn"}) {
                    File graphFile = new File(stage, graph);
                    File weights = new File(stage, graph + ".weight");
                    if (graphFile.length() < 1024L * 1024L && (!weights.isFile() || weights.length() < 1024L))
                        throw new IOException("missing_external_weights_" + graph);
                }
                // Never destroy a previous working installation before the new set is complete.
                File backup = new File(base, "sd15-backup");
                deleteTree(backup);
                if (target.exists() && !target.renameTo(backup)) throw new IOException("backup_failed");
                if (!stage.renameTo(target)) {
                    if (backup.exists()) backup.renameTo(target);
                    throw new IOException("installation_failed");
                }
                deleteTree(backup);
                report("completed", total);
            } catch (Exception e) {
                try { state = new JSONObject().put("state", "error")
                    .put("reason", e.getClass().getSimpleName())
                    .put("detail", String.valueOf(e.getMessage())).toString(); }
                catch (Exception ignored) { state = "{\"state\":\"error\"}"; }
                deleteTree(stage);
            } finally { busy = false; runOnUiThread(this::finish); }
        }, "KarmaSd15ModelImport").start();
    }
    private static void deleteTree(File file) {
        if (!file.exists()) return;
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) for (File child : children) deleteTree(child);
        }
        file.delete();
    }
}
