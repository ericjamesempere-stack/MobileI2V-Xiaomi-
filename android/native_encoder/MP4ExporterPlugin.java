package com.mobilei2v.encoder;

import android.app.Activity;
import android.util.Log;
import androidx.annotation.NonNull;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/** Godot Android plugin v2 singleton name: MP4Exporter. */
public final class MP4ExporterPlugin extends GodotPlugin {
    private final AvcMp4Encoder encoder = new AvcMp4Encoder();

    public MP4ExporterPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "MP4Exporter";
    }

    @UsedByGodot
    public boolean begin(String path, int width, int height, int fps) {
        try {
            encoder.begin(path, width, height, fps);
            return true;
        } catch (Exception ex) {
            Log.e("MobileI2V", "MP4 begin failed", ex);
            return false;
        }
    }

    @UsedByGodot
    public boolean push_frame_rgba(byte[] frame) {
        try {
            encoder.pushFrame(frame);
            return true;
        } catch (Exception ex) {
            Log.e("MobileI2V", "MP4 frame failed", ex);
            return false;
        }
    }

    @UsedByGodot
    public String finish() {
        try {
            return encoder.finish();
        } catch (Exception ex) {
            Log.e("MobileI2V", "MP4 finish failed", ex);
            return "";
        }
    }

    @UsedByGodot
    public void abort() {
        encoder.abort();
    }
}
