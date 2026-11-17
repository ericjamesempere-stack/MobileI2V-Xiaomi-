package com.mobilei2v.encoder;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import org.json.JSONObject;
import java.io.File;
import java.util.UUID;

/** Internal result receiver: survives Godot activity recreation, never exports an URI. */
public final class ReferenceImagePickerActivity extends Activity {
    private static final int SELECT_IMAGE = 31;
    private String request;
    private static java.lang.ref.WeakReference<ReferenceImagePickerActivity> current = new java.lang.ref.WeakReference<>(null);
    private static final java.util.Set<String> decoding = java.util.concurrent.ConcurrentHashMap.newKeySet();
    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences("karma_photo_import_v58", Context.MODE_PRIVATE);
    }
    static synchronized boolean launch(Activity host, String role) {
        if (host == null) return false;
        String id = UUID.randomUUID().toString();
        prefs(host).edit().clear().putString("request", id).putString("role", role)
            .putString("stage", "opening").commit();
        host.runOnUiThread(() -> {
            try {
                Intent intent = new Intent(host, ReferenceImagePickerActivity.class);
                intent.putExtra("request", id);
                host.startActivity(intent);
            } catch (RuntimeException e) { complete(host, id, "error", "Ouverture galerie : " + e.getClass().getSimpleName()); }
        });
        return true;
    }
    static synchronized boolean stage(Context c, String id, String stage) {
        if (!id.equals(prefs(c).getString("request", ""))) return false;
        prefs(c).edit().putString("stage", stage).commit();
        return true;
    }
    static synchronized void complete(Context c, String id, String state, String value) {
        if (!id.equals(prefs(c).getString("request", ""))) {
            if ("selected".equals(state)) new File(value).delete();
            return;
        }
        try {
            JSONObject result = new JSONObject().put("state", state).put("value", value)
                .put("role", prefs(c).getString("role", "reference"));
            prefs(c).edit().putString("result", result.toString()).putString("stage", state).commit();
        } catch (Exception e) { throw new IllegalStateException(e); }
    }
    static synchronized String consume(Context c) {
        String value = prefs(c).getString("result", "");
        if (!value.isEmpty()) prefs(c).edit().remove("result").putString("stage", "idle").commit();
        return value;
    }
    static synchronized String status(Context c) { return prefs(c).getString("stage", "idle"); }
    static synchronized void cancel(Context c) { prefs(c).edit().clear().commit(); }

    @Override protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        request = getIntent().getStringExtra("request");
        if (request == null || !request.equals(prefs(this).getString("request", ""))) { finish(); return; }
        current = new java.lang.ref.WeakReference<>(this);
        if (saved != null) {
            String phase = status(this);
            if (("decoding".equals(phase) || "saving".equals(phase)) && !decoding.contains(request)) {
                complete(this, request, "error", "Android a interrompu le décodage. Projet conservé ; sélectionne à nouveau la photo.");
                finish();
            } else if ("selected".equals(phase) || "cancelled".equals(phase) || "error".equals(phase) || "idle".equals(phase)) {
                finish();
            }
            return; // Existing document picker result is delivered by Android.
        }
        try {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("image/*");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
            stage(this, request, "selecting");
            startActivityForResult(intent, SELECT_IMAGE);
        } catch (RuntimeException e) {
            complete(this, request, "error", "Ouverture sélecteur : " + e.getClass().getSimpleName());
            finish();
        }
    }
    @Override public void onBackPressed() {
        // Back during decoding must invalidate the worker's result, not replace a newer project.
        complete(this, request, "cancelled", "");
        decoding.remove(request);
        prefs(this).edit().remove("request").commit();
        finish();
    }
    @Override protected void onActivityResult(int code, int result, Intent data) {
        super.onActivityResult(code, result, data);
        if (code != SELECT_IMAGE) return;
        if (result != RESULT_OK || data == null || data.getData() == null) {
            complete(this, request, "cancelled", ""); finish(); return;
        }
        Uri uri = data.getData();
        Context context = getApplicationContext();
        String id = request;
        // Keep the granted URI usable until decoding finishes. Private PNG needs no grant afterwards.
        boolean held = false;
        try {
            if ((data.getFlags() & Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION) != 0) {
                getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
                held = true;
            }
        } catch (SecurityException ignored) { /* Temporary read grant still applies. */ }
        final boolean releaseGrant = held;
        decoding.add(id);
        stage(context, id, "decoding");
        new Thread(() -> {
            try {
                String path = ReferenceImageImporter.importImage(context, uri, phase -> stage(context, id, phase));
                complete(context, id, "selected", path);
            } catch (Exception | OutOfMemoryError e) {
                complete(context, id, "error", "Import photo / " + status(context) + " : " + e.getClass().getSimpleName() + ". Projet précédent conservé.");
            } finally {
                if (releaseGrant) {
                    try { context.getContentResolver().releasePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION); }
                    catch (SecurityException ignored) {}
                }
                decoding.remove(id);
                runOnUiThread(() -> {
                    ReferenceImagePickerActivity receiver = current.get();
                    if (receiver != null && id.equals(receiver.request)) receiver.finish();
                    finish();
                });
            }
        }, "KarmaPhotoImport").start();
    }
}
