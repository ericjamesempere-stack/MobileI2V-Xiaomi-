package com.mobilei2v.encoder;

import android.app.Activity;
import android.content.ContentValues;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import java.io.InputStream;
import java.io.FileOutputStream;
import android.content.ContentResolver;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;
import java.io.FileInputStream;
import java.io.OutputStream;
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

    public MP4Exporter(Godot godot) { super(godot); }
    @NonNull @Override public String getPluginName() { return "MP4Exporter"; }

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
            ByteBuffer input = codec.getInputBuffer(slot);
            if (input == null || input.capacity() < width * height * 3 / 2) return false;
            input.clear();
            // I420 planar, accepted by flexible YUV420 encoders that support planar layout.
            int pixels = width * height;
            byte[] yuv = new byte[pixels * 3 / 2];
            int uvWidth = width / 2;
            for (int yy = 0; yy < height; yy++) {
                for (int xx = 0; xx < width; xx++) {
                    int i = (yy * width + xx) * 4;
                    int r = rgba[i] & 255, g = rgba[i+1] & 255, b = rgba[i+2] & 255;
                    int y = ((66*r + 129*g + 25*b + 128) >> 8) + 16;
                    yuv[yy * width + xx] = (byte)Math.max(0, Math.min(255, y));
                    if ((xx & 1) == 0 && (yy & 1) == 0) {
                        int uv = (yy / 2) * uvWidth + xx / 2;
                        int u = ((-38*r - 74*g + 112*b + 128) >> 8) + 128;
                        int v = ((112*r - 94*g - 18*b + 128) >> 8) + 128;
                        yuv[pixels + uv] = (byte)Math.max(0, Math.min(255, u));
                        yuv[pixels + pixels / 4 + uv] = (byte)Math.max(0, Math.min(255, v));
                    }
                }
            }
            input.put(yuv);
            codec.queueInputBuffer(slot, 0, yuv.length, frameIndex++ * 1000000L / fps, 0);
            drain(false);
            return true;
        } catch (Exception e) { error = e.toString(); Log.e("MobileI2V", "Frame encoding failed", e); return false; }
    }

    private void drain(boolean end) {
        if (codec == null) return;
        if (end) {
            int slot = codec.dequeueInputBuffer(1000000);
            if (slot >= 0) codec.queueInputBuffer(slot, 0, 0, frameIndex * 1000000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
        }
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
                if (eos) break;
            } else if (out == MediaCodec.INFO_TRY_AGAIN_LATER && !end) break;
        }
    }

    @UsedByGodot
    public String finish() {
        try {
            if (codec == null || frameIndex == 0) return "";
            drain(true);
            String result = output.getAbsolutePath();
            release(false);
            return result;
        } catch (Exception e) { error = e.toString(); Log.e("MobileI2V", "Finish failed", e); release(true); return ""; }
    }

    private static final int PICK_IMAGE_REQUEST = 61421;
    private volatile String selectedImagePath = "";
    private volatile String pickerError = "";

    @UsedByGodot
    public boolean pick_image() {
        Activity activity = getActivity();
        if (activity == null) return false;
        selectedImagePath = "";
        pickerError = "";
        activity.runOnUiThread(() -> {
            try {
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("image/*");
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                activity.startActivityForResult(intent, PICK_IMAGE_REQUEST);
            } catch (Exception e) { pickerError = e.toString(); }
        });
        return true;
    }

    @Override
    public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != PICK_IMAGE_REQUEST) return;
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            pickerError = "Selection annulee";
            return;
        }
        try {
            Uri uri = data.getData();
            File cache = new File(getActivity().getCacheDir(), "cartoon_import_" + System.currentTimeMillis() + ".png");
            // Decode via Android: supports content://, HEIC, JPEG and PNG, then
            // normalize to PNG so Godot never needs to guess the MIME type.
            try (InputStream input = getActivity().getContentResolver().openInputStream(uri)) {
                if (input == null) throw new IllegalStateException("Document inaccessible");
                BitmapFactory.Options options = new BitmapFactory.Options();
                options.inJustDecodeBounds = true;
                BitmapFactory.decodeStream(input, null, options);
                if (options.outWidth <= 0 || options.outHeight <= 0)
                    throw new IllegalStateException("Image format unsupported");
            }
            Bitmap bitmap;
            try (InputStream input = getActivity().getContentResolver().openInputStream(uri)) {
                BitmapFactory.Options options = new BitmapFactory.Options();
                options.inSampleSize = 2;
                bitmap = BitmapFactory.decodeStream(input, null, options);
            }
            if (bitmap == null) throw new IllegalStateException("Unable to decode selected photo");
            try (FileOutputStream outputStream = new FileOutputStream(cache)) {
                if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream))
                    throw new IllegalStateException("Unable to save PNG");
            } finally {
                bitmap.recycle();
            }
            selectedImagePath = cache.getAbsolutePath();
        } catch (Exception e) {
            pickerError = e.toString();
            Log.e("MobileI2V", "Photo import failed", e);
        }
    }

    @UsedByGodot public String take_selected_image_path() {
        String value = selectedImagePath;
        selectedImagePath = "";
        return value;
    }
    @UsedByGodot public String take_image_picker_error() {
        String value = pickerError;
        pickerError = "";
        return value;
    }

    // Publish a finished video in the user's Downloads collection (Android 10+).
    // The original app-private MP4 is preserved if publishing fails.
    @UsedByGodot
    public String publish_to_downloads(String sourcePath) {
        Activity activity = getActivity();
        if (activity == null || Build.VERSION.SDK_INT < 29) {
            error = "Downloads publishing requires Android 10 or newer";
            return "";
        }
        File source = new File(sourcePath);
        if (!source.isFile() || source.length() < 1024) {
            error = "Source MP4 is missing or empty";
            return "";
        }
        ContentResolver resolver = activity.getContentResolver();
        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, "CartoonStudio_" + System.currentTimeMillis() + ".mp4");
        values.put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4");
        values.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/CartoonStudio");
        values.put(MediaStore.MediaColumns.IS_PENDING, 1);
        Uri uri = null;
        try {
            uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            if (uri == null) throw new IllegalStateException("MediaStore insert failed");
            try (FileInputStream input = new FileInputStream(source);
                 OutputStream outputStream = resolver.openOutputStream(uri)) {
                if (outputStream == null) throw new IllegalStateException("MediaStore output unavailable");
                byte[] buffer = new byte[65536];
                int read;
                while ((read = input.read(buffer)) != -1) outputStream.write(buffer, 0, read);
            }
            ContentValues ready = new ContentValues();
            ready.put(MediaStore.MediaColumns.IS_PENDING, 0);
            resolver.update(uri, ready, null, null);
            return uri.toString();
        } catch (Exception e) {
            error = e.toString();
            Log.e("MobileI2V", "Publishing MP4 failed", e);
            if (uri != null) resolver.delete(uri, null, null);
            return "";
        }
    }

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
