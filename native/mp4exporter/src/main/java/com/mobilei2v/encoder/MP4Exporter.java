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
import org.json.JSONObject;
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

    @NonNull @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(
            new SignalInfo("reference_image_selected", String.class),
            new SignalInfo("reference_image_error", String.class),
            new SignalInfo("reference_image_cancelled")));
    }

    // The internal receiver persists a mailbox across Godot/Android recreation.
    @UsedByGodot public String consume_reference_image_result() {
        return ReferenceImagePickerActivity.consume(getGodot().getContext());
    }
    @UsedByGodot public String reference_image_import_status() {
        return ReferenceImagePickerActivity.status(getGodot().getContext());
    }
    @UsedByGodot public void cancel_reference_image_import() {
        ReferenceImagePickerActivity.cancel(getGodot().getContext());
    }
    @UsedByGodot public void prefer_document_image_picker() {
        ReferenceImagePickerActivity.preferDocumentPicker(getGodot().getContext());
    }
    @UsedByGodot public boolean pick_reference_image() {
        return pick_reference_image_for_role("reference");
    }
    @UsedByGodot public boolean pick_reference_image_for_role(String role) {
        return ReferenceImagePickerActivity.launch(getActivity(), Arrays.asList("style", "board", "replacement").contains(role) ? role : "reference");
    }

    @UsedByGodot public String local_engine_installation_status() {
        JSONObject report = new JSONObject();
        for (String name : new String[]{"io.github.xororz.localdream", "com.alibaba.mnnllm.android", "com.alibaba.mnnllm.android.release"}) {
            try {
                android.content.pm.PackageInfo pkg = getContext().getPackageManager().getPackageInfo(name, 0);
                report.put(name, new JSONObject().put("installed", true).put("version", pkg.versionName));
            } catch (android.content.pm.PackageManager.NameNotFoundException e) {
                try { report.put(name, new JSONObject().put("installed", false)); } catch (Exception ignored) {}
            } catch (Exception e) {
                try { report.put(name, new JSONObject().put("status", "unknown")); } catch (Exception ignored) {}
            }
        }
        return report.toString();
    }

    // Real on-device readiness: this does not claim successful model inference.
    // Use the app-private files directory; never trust a caller-supplied absolute path.
    @UsedByGodot public String native_sd15_readiness() {
        JSONObject report = new JSONObject();
        try {
            boolean librariesLoaded = com.mobilei2v.mnn.KarmaMnnBridge.isAvailable();
            File models = new File(getContext().getFilesDir(), "models/sd15");
            JSONObject components = new JSONObject();
            boolean filesPresent = true;
            for (String name : new String[]{"tokenizer.mtok", "text_encoder.mnn", "unet.mnn", "vae_decoder.mnn"}) {
                File file = new File(models, name);
                boolean present = file.isFile() && file.length() > 0;
                components.put(name, new JSONObject().put("present", present)
                        .put("bytes", present ? file.length() : 0));
                filesPresent &= present;
            }
            report.put("ok", librariesLoaded && filesPresent);
            report.put("native_libraries_loaded", librariesLoaded);
            report.put("model_files_present", filesPresent);
            report.put("components", components);
            report.put("inference_verified", false);
            report.put("reason", !librariesLoaded ? "mnn_native_library_unavailable"
                    : !filesPresent ? "sd15_model_files_missing" : "inference_not_tested");
        } catch (Exception e) {
            try { report.put("ok", false).put("inference_verified", false)
                    .put("reason", "native_readiness_check_failed"); } catch (Exception ignored) {}
        }
        return report.toString();
    }

    private volatile String nativeSd15Job = "{\"state\":\"idle\"}";
    private volatile boolean nativeSd15Busy = false;

    // Runs the EXISTING CLIP -> UNet -> DDIM -> VAE pipeline on a worker thread.
    // It is text-to-image only; it must never be used to claim image-to-image fidelity.
    @UsedByGodot public synchronized boolean start_native_sd15(String prompt, String negativePrompt) {
        if (nativeSd15Busy || prompt == null || prompt.trim().isEmpty() || prompt.length() > 4000
                || negativePrompt == null || negativePrompt.length() > 4000) return false;
        File dir = new File(getContext().getFilesDir(), "models/sd15");
        String[] names = {"tokenizer.mtok", "text_encoder.mnn", "unet.mnn", "vae_decoder.mnn"};
        if (!com.mobilei2v.mnn.KarmaMnnBridge.isAvailable()) {
            nativeSd15Job = "{\"state\":\"error\",\"error\":\"mnn_native_library_unavailable\"}";
            return false;
        }
        for (String name : names) if (!new File(dir, name).isFile()) {
            nativeSd15Job = "{\"state\":\"error\",\"error\":\"sd15_model_files_missing\"}";
            return false;
        }
        nativeSd15Busy = true;
        nativeSd15Job = "{\"state\":\"running\"}";
        File outputDir = new File(getContext().getFilesDir(), "generated_sd15");
        final String positive = prompt;
        final String negative = negativePrompt;
        new Thread(() -> {
            try {
                if (!outputDir.isDirectory() && !outputDir.mkdirs())
                    throw new java.io.IOException("output_directory_creation_failed");
                com.mobilei2v.mnn.KarmaSdInference.Config cfg =
                        new com.mobilei2v.mnn.KarmaSdInference.Config();
                cfg.unetPath = new File(dir, "unet.mnn").getAbsolutePath();
                cfg.vaePath = new File(dir, "vae_decoder.mnn").getAbsolutePath();
                cfg.outputPng = new File(outputDir, "native_sd15_" + System.currentTimeMillis() + ".png").getAbsolutePath();
                cfg.steps = 8;
                // SD1.5 linear beta schedule: 1000 training timesteps.
                cfg.alphasCumprod = new float[1000];
                double alpha = 1.0;
                for (int i = 0; i < 1000; ++i) {
                    double beta = 0.00085 + (0.012 - 0.00085) * i / 999.0;
                    alpha *= 1.0 - beta;
                    cfg.alphasCumprod[i] = (float) alpha;
                }
                cfg.timesteps = new int[cfg.steps];
                for (int i = 0; i < cfg.steps; ++i)
                    cfg.timesteps[i] = (cfg.steps - i - 1) * (1000 / cfg.steps);
                File result = com.mobilei2v.mnn.KarmaSdInference.generatePrompt(cfg,
                        new File(dir, "tokenizer.mtok").getAbsolutePath(),
                        new File(dir, "text_encoder.mnn").getAbsolutePath(), negative, positive);
                JSONObject success = new JSONObject().put("state", "completed")
                        .put("file", result.getAbsolutePath()).put("bytes", result.length())
                        .put("inference_verified", result.isFile() && result.length() > 0);
                nativeSd15Job = success.toString();
            } catch (Exception e) {
                try { nativeSd15Job = new JSONObject().put("state", "error")
                        .put("error", e.getClass().getSimpleName())
                        .put("detail", String.valueOf(e.getMessage())).toString(); }
                catch (Exception ignored) { nativeSd15Job = "{\"state\":\"error\",\"error\":\"native_generation_failed\"}"; }
            } finally { nativeSd15Busy = false; }
        }, "KarmaNativeSd15").start();
        return true;
    }

    @UsedByGodot public String native_sd15_job_status() { return nativeSd15Job; }

    @UsedByGodot public String peek_shared_image_result() { return SharedImageInbox.peek(getContext()); }
    @UsedByGodot public void acknowledge_shared_image(String id) { SharedImageInbox.acknowledge(getContext(), id); }

    private volatile String chatgptShareResult = "";
    private volatile boolean chatgptSharing = false;
    @UsedByGodot public String consume_chatgpt_share_result() {
        String result = chatgptShareResult; chatgptShareResult = ""; return result;
    }
    @UsedByGodot public synchronized boolean share_chatgpt_reference(String path, String prompt) {
        Activity activity = getActivity();
        if (activity == null || chatgptSharing || prompt == null || prompt.trim().isEmpty() || prompt.length() > 24000) return false;
        chatgptSharing = true;
        chatgptShareResult = "";
        new Thread(() -> {
            try {
                Intent intent = new Intent(Intent.ACTION_SEND);
                intent.putExtra(Intent.EXTRA_TEXT, prompt);
                intent.setType("text/plain");
                if (path != null && !path.isEmpty()) {
                    File source = new File(path).getCanonicalFile();
                    File privateRoot = activity.getFilesDir().getCanonicalFile();
                    if (!source.getPath().startsWith(privateRoot.getPath() + File.separator) || !source.isFile() || source.length() > 32000000)
                        throw new IllegalArgumentException("Reference privée invalide ou trop volumineuse");
                    File folder = new File(activity.getCacheDir(), "karma_shares");
                    if (!folder.isDirectory() && !folder.mkdirs()) throw new IllegalStateException("Cache de partage inaccessible");
                    File copy = new File(folder, java.util.UUID.randomUUID().toString() + ".png");
                    try (FileInputStream input = new FileInputStream(source); java.io.FileOutputStream output = new java.io.FileOutputStream(copy)) {
                        byte[] buffer = new byte[65536]; int count;
                        while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                    }
                    Uri uri = Uri.parse("content://" + activity.getPackageName() + ".karma.references/" + copy.getName());
                    intent.setType("image/png");
                    intent.putExtra(Intent.EXTRA_STREAM, uri);
                    intent.setClipData(android.content.ClipData.newRawUri("KARMA reference", uri));
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                }
                activity.runOnUiThread(() -> {
                    try {
                        Intent target = new Intent(intent).setPackage("com.openai.chatgpt");
                        if (activity.getPackageManager().resolveActivity(target, 0) != null) activity.startActivity(target);
                        else activity.startActivity(Intent.createChooser(intent, "Choisis ChatGPT"));
                        chatgptShareResult = "opened";
                    } catch (RuntimeException e) { chatgptShareResult = "error: " + e.getClass().getSimpleName(); }
                    finally { chatgptSharing = false; }
                });
            } catch (Exception e) {
                chatgptShareResult = "error: " + e.getClass().getSimpleName();
                chatgptSharing = false;
            }
        }, "KarmaChatGPTShare").start();
        return true;
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
                    activity.getSharedPreferences("karma_video_v60",0).edit().putString("last_uri",uri.toString()).apply();
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
        final Uri uri = savedExportUri();
        if (activity == null || uri == null) return false;
        activity.runOnUiThread(() -> {
            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.setType("video/mp4");
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.startActivity(Intent.createChooser(intent, "Partager le MP4"));
        });
        return true;
    }

    private Uri savedExportUri() {
        if (lastExportUri != null) return lastExportUri;
        String saved = getContext().getSharedPreferences("karma_video_v60",0).getString("last_uri", "");
        if (saved.isEmpty()) return null;
        Uri uri = Uri.parse(saved);
        return "content".equals(uri.getScheme()) && "media".equals(uri.getAuthority()) ? uri : null;
    }
    @UsedByGodot public boolean play_last_export() {
        Activity activity = getActivity();
        Uri uri = savedExportUri();
        if (activity == null || uri == null) return false;
        activity.runOnUiThread(() -> {
            try {
                Intent play = new Intent(Intent.ACTION_VIEW).setDataAndType(uri, "video/mp4");
                play.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                activity.startActivity(play);
            } catch (RuntimeException e) {
                error = "Lecteur Android indisponible ou vidéo déplacée.";
                android.widget.Toast.makeText(activity,error,android.widget.Toast.LENGTH_LONG).show();
            }
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
