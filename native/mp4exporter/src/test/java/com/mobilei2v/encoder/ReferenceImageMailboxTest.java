package com.mobilei2v.encoder;
import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import java.io.File;
import static org.junit.Assert.*;

/** Lifecycle regression with Android framework simulation, NOT a real device test. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class ReferenceImageMailboxTest {
    @Test public void durableResultDoesNotDependOnGodotPluginInstance() throws Exception {
        Activity host = Robolectric.buildActivity(Activity.class).setup().get();
        assertTrue(ReferenceImagePickerActivity.launch(host, "style"));
        Context context = host.getApplicationContext();
        SharedPreferences prefs = context.getSharedPreferences("karma_photo_import_v58", 0);
        String id = prefs.getString("request", "");
        assertFalse(id.isEmpty());
        assertTrue(ReferenceImagePickerActivity.stage(context, id, "decoding"));
        ReferenceImagePickerActivity.complete(context, id, "selected", "/private/reference.png");
        JSONObject result = new JSONObject(ReferenceImagePickerActivity.consume(context));
        assertEquals("selected", result.getString("state"));
        assertEquals("style", result.getString("role"));
        assertEquals("", ReferenceImagePickerActivity.consume(context));
    }
    @Test public void cancelledOrSupersededWorkCannotReplaceNewerSelection() throws Exception {
        Activity host = Robolectric.buildActivity(Activity.class).setup().get();
        ReferenceImagePickerActivity.launch(host, "reference");
        Context context = host.getApplicationContext();
        String old = context.getSharedPreferences("karma_photo_import_v58", 0).getString("request", "");
        ReferenceImagePickerActivity.cancel(context);
        ReferenceImagePickerActivity.launch(host, "style");
        File orphan = File.createTempFile("cancelled_import", ".png", context.getFilesDir());
        ReferenceImagePickerActivity.complete(context, old, "selected", orphan.getAbsolutePath());
        assertFalse(orphan.exists());
        assertEquals("", ReferenceImagePickerActivity.consume(context));
        assertFalse(ReferenceImagePickerActivity.stage(context, old, "saving"));
    }
}
