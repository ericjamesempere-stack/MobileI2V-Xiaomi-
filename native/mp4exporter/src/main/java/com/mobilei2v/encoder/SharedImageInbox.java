package com.mobilei2v.encoder;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.Intent;
import android.net.Uri;
import org.json.JSONObject;
import java.util.UUID;

/** A single private pending image. Receipt never changes a Godot project. */
public final class SharedImageInbox {
    private SharedImageInbox() {}
    private static SharedPreferences prefs(Context c) { return c.getSharedPreferences("karma_shared_image_v60", Context.MODE_PRIVATE); }
    static Uri imageUri(Intent intent) {
        if (intent == null || !Intent.ACTION_SEND.equals(intent.getAction()) || intent.getType() == null || !intent.getType().startsWith("image/")) return null;
        Uri uri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
        if (uri == null && intent.getClipData() != null && intent.getClipData().getItemCount() == 1) uri = intent.getClipData().getItemAt(0).getUri();
        return uri != null && "content".equals(uri.getScheme()) && uri.getAuthority() != null ? uri : null;
    }
    static synchronized String begin(Context c) {
        if (!prefs(c).getString("id", "").isEmpty()) return "";
        String id = UUID.randomUUID().toString();
        prefs(c).edit().putString("id", id).putString("state", "decoding").putLong("started_at",System.currentTimeMillis()).commit(); return id;
    }
    static synchronized String current(Context c) { return prefs(c).getString("id", ""); }
    static synchronized void complete(Context c, String id, String state, String value) {
        if (id.isEmpty() || !id.equals(current(c)) || !prefs(c).getString("result", "").isEmpty()) return;
        try {
            prefs(c).edit().putString("state", state).putString("result", new JSONObject().put("id",id).put("state",state).put("value",value).toString()).commit();
        } catch (Exception e) { throw new IllegalStateException(e); }
    }
    static synchronized String peek(Context c) {
        String result = prefs(c).getString("result", "");
        if (result.isEmpty() && !current(c).isEmpty() && System.currentTimeMillis() - prefs(c).getLong("started_at",0) > 120000) {
            complete(c,current(c),"error","Réception interrompue ou trop longue. Le projet est conservé ; partage à nouveau l'image.");
            result = prefs(c).getString("result", "");
        }
        return result;
    }
    static synchronized void acknowledge(Context c, String id) {
        if (id.equals(current(c))) prefs(c).edit().clear().commit();
    }
}
