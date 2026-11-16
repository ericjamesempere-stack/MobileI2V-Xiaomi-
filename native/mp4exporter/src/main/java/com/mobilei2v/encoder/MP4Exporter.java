package com.mobilei2v.encoder;

import android.app.Activity;
import android.content.ContentValues;
import android.content.Intent;
import android.net.Uri;
import android.provider.MediaStore;
import java.io.FileInputStream;
import java.io.OutputStream;
import android.media.Image;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.os.Build;
import android.util.Log;
import androidx.annotation.NonNull;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.godotengine.godot.plugin.SignalInfo;
import java.util.Set;
import java.util.HashSet;
import java.util.Arrays;
import java.io.File;
import java.nio.ByteBuffer;

public final class MP4Exporter extends GodotPlugin {
    private MediaCodec codec;
    private MediaMuxer muxer;
    private int track = -1;
    private boolean muxerStarted = false;
    private int width, height, fps;
    private long frameIndex = 0;
    private File output;
    private final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
    private String error = "";
    private Uri lastExportUri;

    public MP4Exporter(Godot godot) { super(godot); }
    @NonNull @Override public String getPluginName() { return "MP4Exporter"; }

    private static final int PHOTO_REQUEST = 24071;
    private volatile boolean pickingPhoto = false;

    @NonNull @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(
            new SignalInfo("reference_image_selected", String.class),
            new SignalInfo("reference_image_error", String.class),
            new SignalInfo("reference_image_cancelled")));
    }

    @UsedByGodot public boolean pick_reference_image() {
        Activity activity = getActivity();
        if (activity == null || pickingPhoto) return false;
        pickingPhoto = true;
        activity.runOnUiThread(() -> {
            try {
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("image/*");
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                activity.startActivityForResult(intent, PHOTO_REQUEST);
            } catch (Exception e) {
                pickingPhoto = false;
                emitSignal("reference_image_error", "Impossible d'ouvrir la galerie Android.");
            }
        });
        return true;
    }

    @Override public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != PHOTO_REQUEST) return;
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            pickingPhoto = false;
            emitSignal("reference_image_cancelled");
            return;
        }
        final Uri uri = data.getData();
        new Thread(() -> {
            try {
                String localPath = ReferenceImageImporter.importImage(getActivity(), uri);
                emitSignal("reference_image_selected", localPath);
            } catch (Exception e) {
                Log.w("MobileI2V", "Reference import failed: " + e.getClass().getSimpleName());
                emitSignal("reference_image_error", "Cette image n'a pas pu être importée. Essaie une autre image.");
            } finally { pickingPhoto = false; }
        }, "KarmaPhotoImport").start();
    }

    @UsedByGodot public String import_reference_uri(String uri) {
        try { return ReferenceImageImporter.importImage(getActivity(), Uri.parse(uri)); }
        catch (Exception e) { error = "Import photo impossible : " + e.getClass().getSimpleName(); return ""; }
    }

    @UsedByGodot
    public boolean begin(String requestedPath, int w, int h, int frameRate) {
        release(false);
        if (w <= 0 || h <= 0 || (w % 2) != 0 || (h % 2) != 0 || frameRate <= 0) return false;
        try {
            Activity activity = getActivity();
            if (activity == null) throw new IllegalStateException("No Android activity");
            File dir = new File(activity.getExternalFilesDir(null), "exports");
            if (!dir.exists() && !dir.mkdirs()) throw new IllegalStateException("Cannot create export folder");
            output = new File(dir, "MobileI2V_" + System.currentTimeMillis() + ".mp4");
            width = w; height = h; fps = frameRate; frameIndex = 0;
            track = -1; muxerStarted = false; error = "";
            MediaFormat format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h);
            format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible);
            format.setInteger(MediaFormat.KEY_BIT_RATE, Math.max(1_500_000, w * h * 4));
            format.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
            format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
            codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            codec.start();
            muxer = new MediaMuxer(output.getAbsolutePath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            return true;
        } catch (Exception e) { error = e.toString(); Log.e("MobileI2V", "Encoder begin failed", e); release(true); return false; }
    }

    @UsedByGodot
    public boolean push_frame_rgba(byte[] rgba) {
        if (codec == null || rgba == null || rgba.length != width * height * 4) return false;
        try {
            int slot = codec.dequeueInputBuffer(1000000);
            if (slot < 0) return false;
            // Flexible YUV is not necessarily packed I420 on MediaTek.
            // Respect each encoder plane's actual row and pixel strides.
            Image image = codec.getInputImage(slot);
            if (image == null) throw new IllegalStateException("Encoder has no flexible YUV input image");
            try {
                Image.Plane[] planes = image.getPlanes();
                if (planes.length != 3) throw new IllegalStateException("Expected three YUV planes");
                for (int yy = 0; yy < height; yy++) {
                    for (int xx = 0; xx < width; xx++) {
                        int i = (yy * width + xx) * 4;
                        int r = rgba[i] & 255, g = rgba[i + 1] & 255, b = rgba[i + 2] & 255;
                        int y = ((66*r + 129*g + 25*b + 128) >> 8) + 16;
                        putPlane(planes[0], xx, yy, y);
                        if ((xx & 1) == 0 && (yy & 1) == 0) {
                            int u = ((-38*r - 74*g + 112*b + 128) >> 8) + 128;
                            int v = ((112*r - 94*g - 18*b + 128) >> 8) + 128;
                            putPlane(planes[1], xx / 2, yy / 2, u);
                            putPlane(planes[2], xx / 2, yy / 2, v);
                        }
                    }
                }
            } finally { image.close(); }
            codec.queueInputBuffer(slot, 0, width * height * 3 / 2, frameIndex++ * 1000000L / fps, 0);
            drain(false);
            return true;
        } catch (Exception e) { error = e.toString(); Log.e("MobileI2V", "Frame encoding failed", e); return false; }
    }

    private static void putPlane(Image.Plane plane, int x, int y, int value) {
        ByteBuffer buffer = plane.getBuffer();
        buffer.put(buffer.position() + y * plane.getRowStride() + x * plane.getPixelStride(),
                   (byte)Math.max(0, Math.min(255, value)));
    }

    private void drain(boolean end) {
        if (codec == null) return;
        if (end) {
            int slot = codec.dequeueInputBuffer(1000000);
            if (slot < 0) throw new IllegalStateException("Could not queue end of stream");
            codec.queueInputBuffer(slot, 0, 0, frameIndex * 1000000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
        }
        boolean sawEnd = false;
        for (int attempts = 0; attempts < (end ? 200 : 16); attempts++) {
            int out = codec.dequeueOutputBuffer(info, end ? 100000 : 10000);
            if (out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (muxerStarted) throw new IllegalStateException("Output format changed twice");
                track = muxer.addTrack(codec.getOutputFormat());
                muxer.start(); muxerStarted = true;
            } else if (out >= 0) {
                ByteBuffer buffer = codec.getOutputBuffer(out);
                if (buffer != null && info.size > 0 && muxerStarted && (info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                    buffer.position(info.offset); buffer.limit(info.offset + info.size);
                    muxer.writeSampleData(track, buffer, info);
                }
                boolean eos = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
                codec.releaseOutputBuffer(out, false);
                if (eos) { sawEnd = true; break; }
            } else if (out == MediaCodec.INFO_TRY_AGAIN_LATER && !end) break;
        }
        if (end && !sawEnd) throw new IllegalStateException("Encoder did not finish stream");
    }

    @UsedByGodot
    public String finish() {
        try {
            if (codec == null || frameIndex == 0) return "";
            drain(true);
            if (!muxerStarted) throw new IllegalStateException("No encoded video track");
            muxer.stop();
            muxerStarted = false;
            File completed = output;
            release(false);
            if (Build.VERSION.SDK_INT >= 29) {
                Activity activity = getActivity();
                ContentValues values = new ContentValues();
                values.put(MediaStore.Video.Media.DISPLAY_NAME, completed.getName());
                values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
                values.put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/KARMA ONE");
                values.put(MediaStore.Video.Media.IS_PENDING, 1);
                Uri uri = activity.getContentResolver().insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
                if (uri == null) throw new IllegalStateException("Cannot create gallery video");
                try {
                    try (FileInputStream source = new FileInputStream(completed);
                         OutputStream target = activity.getContentResolver().openOutputStream(uri)) {
                        if (target == null) throw new IllegalStateException("Cannot write gallery video");
                        byte[] bytes = new byte[65536];
                        int length;
                        while ((length = source.read(bytes)) != -1) target.write(bytes, 0, length);
                    }
                    values.clear();
                    values.put(MediaStore.Video.Media.IS_PENDING, 0);
                    activity.getContentResolver().update(uri, values, null, null);
                    lastExportUri = uri;
                    completed.delete();
                    return "Movies/KARMA ONE/" + completed.getName();
                } catch (Exception e) {
                    activity.getContentResolver().delete(uri, null, null);
                    throw e;
                }
            }
            return completed.getAbsolutePath();
        } catch (Exception e) { error = e.toString(); Log.e("MobileI2V", "Finish failed", e); release(true); return ""; }
    }

    @UsedByGodot
    public boolean share_last_export() {
        Activity activity = getActivity();
        if (activity == null || lastExportUri == null) return false;
        final Uri uri = lastExportUri;
        activity.runOnUiThread(() -> {
            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.setType("video/mp4");
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.startActivity(Intent.createChooser(intent, "Partager le MP4"));
        });
        return true;
    }

    @UsedByGodot public void abort() { release(true); }

    @UsedByGodot public String get_last_error() { return error; }

    private void release(boolean delete) {
        if (codec != null) {
            try { codec.stop(); } catch (Exception ignored) {}
            try { codec.release(); } catch (Exception ignored) {}
            codec = null;
        }
        if (muxer != null) {
            try { if (muxerStarted) muxer.stop(); } catch (Exception ignored) {}
            try { muxer.release(); } catch (Exception ignored) {}
            muxer = null;
        }
        if (delete && output != null) output.delete();
        muxerStarted = false;
    }
}
