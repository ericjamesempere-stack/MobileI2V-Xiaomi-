package com.mobilei2v.encoder;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;
import androidx.annotation.NonNull;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import ai.onnxruntime.OnnxTensor;
import ai.onnxruntime.OrtEnvironment;
import ai.onnxruntime.OrtSession;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.FloatBuffer;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import org.json.JSONObject;

/**
 * Real CPU inference using ONNX Runtime Android. Contract: float32 NCHW
 * image-to-image ONNX model with input [1,3,H,W], output [1,3,H,W],
 * normalized 0..1. Requires a separately supplied compatible trained model.
 * This is NOT Stable Diffusion or text-to-image; it never fakes pose generation.
 */
public final class ReferencePoseGeneratorPlugin extends GodotPlugin {
    private OrtEnvironment environment;
    private OrtSession session;
    private String loadedPath = "";
    private String error = "model_not_loaded";
    private boolean verified = false;

    public ReferencePoseGeneratorPlugin(Godot godot) { super(godot); }

    @NonNull @Override public String getPluginName() { return "ReferencePoseGenerator"; }

    @UsedByGodot
    public synchronized boolean load_model(String path) {
        unload_model();
        try {
            if (path == null || !new File(path).isFile())
                throw new IllegalArgumentException("model_missing");
            environment = OrtEnvironment.getEnvironment();
            OrtSession.SessionOptions options = new OrtSession.SessionOptions();
            options.setIntraOpNumThreads(4);
            try {
                session = environment.createSession(path, options);
            } finally {
                options.close();
            }
            loadedPath = path;
            error = "";
            return true;
        } catch (Exception ex) {
            error = "onnx_load_failed: " + ex.getMessage();
            Log.e("MobileI2V", error, ex);
            return false;
        }
    }

    @UsedByGodot
    public synchronized boolean is_model_ready() { return session != null; }

    @UsedByGodot
    public synchronized String get_last_error() { return error; }

    @UsedByGodot
    public synchronized boolean generate_pose_png(String json, String outputPath) {
        try {
            JSONObject request = new JSONObject(json);
            String path = request.getString("model_path");
            if (session == null || !loadedPath.equals(path) && !load_model(path))
                throw new IllegalStateException("model_load_failed");
            String reference = request.optString("reference_styled",
                request.optString("reference_original", ""));
            Bitmap original = BitmapFactory.decodeFile(reference);
            if (original == null) throw new IllegalArgumentException("reference_unreadable");
            // Only models with explicitly declared NCHW image input and output
            // can use this generic runner; unsupported diffusion graphs fail.
            String inputName = session.getInputNames().iterator().next();
            ai.onnxruntime.NodeInfo node = session.getInputInfo().get(inputName);
            if (!(node.getInfo() instanceof ai.onnxruntime.TensorInfo))
                throw new IllegalStateException("model_input_not_tensor");
            long[] shape = ((ai.onnxruntime.TensorInfo) node.getInfo()).getShape();
            if (shape.length != 4 || shape[0] != 1 || shape[1] != 3 ||
                shape[2] <= 0 || shape[3] <= 0 || shape[2] > 2048 || shape[3] > 2048)
                throw new IllegalStateException("unsupported_input_shape");
            int h = (int)shape[2], w = (int)shape[3];
            Bitmap resized = Bitmap.createScaledBitmap(original, w, h, true);
            int[] pixels = new int[w * h];
            resized.getPixels(pixels, 0, w, 0, 0, w, h);
            float[] data = new float[3 * w * h];
            for (int i = 0; i < pixels.length; i++) {
                int p = pixels[i];
                data[i] = ((p >>> 16) & 255) / 255f;
                data[w * h + i] = ((p >>> 8) & 255) / 255f;
                data[2 * w * h + i] = (p & 255) / 255f;
            }
            try (OnnxTensor tensor = OnnxTensor.createTensor(environment,
                    FloatBuffer.wrap(data), new long[]{1, 3, h, w});
                 OrtSession.Result result = session.run(Collections.singletonMap(inputName, tensor))) {
                if (result.size() < 1 || !(result.get(0) instanceof OnnxTensor))
                    throw new IllegalStateException("unsupported_output");
                OnnxTensor out = (OnnxTensor) result.get(0);
                long[] outShape = out.getInfo().getShape();
                if (outShape.length != 4 || outShape[0] != 1 || outShape[1] != 3 ||
                    outShape[2] != h || outShape[3] != w)
                    throw new IllegalStateException("unsupported_output_shape");
                FloatBuffer values = out.getFloatBuffer();
                float[] rgb = new float[3 * w * h];
                values.get(rgb);
                int[] generated = new int[w * h];
                for (int i = 0; i < generated.length; i++) {
                    int red = clamp(Math.round(rgb[i] * 255));
                    int green = clamp(Math.round(rgb[w * h + i] * 255));
                    int blue = clamp(Math.round(rgb[2 * w * h + i] * 255));
                    generated[i] = 0xff000000 | (red << 16) | (green << 8) | blue;
                }
                Bitmap bitmap = Bitmap.createBitmap(generated, w, h, Bitmap.Config.ARGB_8888);
                File target = new File(outputPath);
                File parent = target.getParentFile();
                if (parent != null && !parent.exists() && !parent.mkdirs())
                    throw new IllegalStateException("output_directory_failed");
                try (FileOutputStream stream = new FileOutputStream(target)) {
                    if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream))
                        throw new IllegalStateException("png_encoding_failed");
                }
            }
            verified = true;
            error = "";
            return true;
        } catch (Exception ex) {
            error = "onnx_inference_failed: " + ex.getMessage();
            Log.e("MobileI2V", error, ex);
            return false;
        }
    }

    @UsedByGodot
    public synchronized String get_model_status_json() {
        return "{\"inference_verified\":" + verified + ",\"ready\":" + (session != null) + "}";
    }

    @UsedByGodot
    public synchronized void unload_model() {
        if (session != null) try { session.close(); } catch (Exception ignored) {}
        session = null;
        loadedPath = "";
        verified = false;
    }

    private static int clamp(int x) { return Math.max(0, Math.min(255, x)); }
}
