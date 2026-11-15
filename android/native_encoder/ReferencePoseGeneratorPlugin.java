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
import java.util.Arrays;
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
            validateModelContract();
            loadedPath = path;
            error = "";
            return true;
        } catch (Exception ex) {
            unload_model();
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
            if ((session == null || !loadedPath.equals(path)) && !load_model(path))
                throw new IllegalStateException("model_load_failed");
            String reference = request.optString("reference_styled",
                request.optString("reference_original", ""));
            Bitmap original = BitmapFactory.decodeFile(reference);
            if (original == null) throw new IllegalArgumentException("reference_unreadable");
            // Only models with explicitly declared NCHW image input and output
            // can use this generic runner; unsupported diffusion graphs fail.
            if (session.getInputNames().size() != 2)
                throw new IllegalStateException("pose_conditioned_model_requires_image_and_pose_inputs");
            String inputName = request.optString("image_input", "image");
            String poseName = request.optString("pose_input", "pose");
            if (!session.getInputNames().contains(inputName) || !session.getInputNames().contains(poseName) || inputName.equals(poseName))
                throw new IllegalStateException("model_missing_image_or_pose_input");
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
            // Pose conditioning is explicit: a separate 1x3xHxW pose tensor
            // contains normalized target skeleton coordinates encoded as RGB.
            // No pose input means no animation claim.
            String posePath = request.optString("pose_map_path", "");
            Bitmap poseBitmap = BitmapFactory.decodeFile(posePath);
            if (poseBitmap == null) throw new IllegalArgumentException("pose_map_missing");
            ai.onnxruntime.NodeInfo poseNode = session.getInputInfo().get(poseName);
            if (!(poseNode.getInfo() instanceof ai.onnxruntime.TensorInfo))
                throw new IllegalStateException("pose_input_not_tensor");
            long[] poseShape = ((ai.onnxruntime.TensorInfo) poseNode.getInfo()).getShape();
            if (poseShape.length != 4 || poseShape[0] != 1 || poseShape[1] != 3 ||
                poseShape[2] != h || poseShape[3] != w)
                throw new IllegalStateException("pose_input_shape_mismatch");
            Bitmap poseResized = Bitmap.createScaledBitmap(poseBitmap, w, h, true);
            int[] posePixels = new int[w * h];
            poseResized.getPixels(posePixels, 0, w, 0, 0, w, h);
            float[] poseData = new float[3 * w * h];
            for (int i = 0; i < posePixels.length; i++) {
                int p = posePixels[i];
                poseData[i] = ((p >>> 16) & 255) / 255f;
                poseData[w * h + i] = ((p >>> 8) & 255) / 255f;
                poseData[2 * w * h + i] = (p & 255) / 255f;
            }
            try (OnnxTensor poseTensor = OnnxTensor.createTensor(environment,
                    FloatBuffer.wrap(poseData), new long[]{1, 3, h, w});
                 OnnxTensor tensor = OnnxTensor.createTensor(environment,
                    FloatBuffer.wrap(data), new long[]{1, 3, h, w});
                 OrtSession.Result result = session.run(Map.of(inputName, tensor, poseName, poseTensor))) {
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


    /**
     * Reject incompatible generic ONNX models at installation time rather than
     * misleadingly reporting them as a working pose-conditioned generator.
     */
    private void validateModelContract() throws Exception {
        if (session == null || session.getInputNames().size() != 2 || session.getOutputNames().size() != 1)
            throw new IllegalArgumentException("expected_two_inputs_and_one_output");
        for (String name : new String[]{"image", "pose"}) {
            ai.onnxruntime.NodeInfo node = session.getInputInfo().get(name);
            if (node == null || !(node.getInfo() instanceof ai.onnxruntime.TensorInfo))
                throw new IllegalArgumentException("missing_tensor_input_" + name);
            ai.onnxruntime.TensorInfo tensor = (ai.onnxruntime.TensorInfo) node.getInfo();
            long[] shape = tensor.getShape();
            if (tensor.type != ai.onnxruntime.OnnxJavaType.FLOAT || shape.length != 4 ||
                shape[0] != 1 || shape[1] != 3 || shape[2] <= 0 || shape[3] <= 0 ||
                shape[2] > 1024 || shape[3] > 1024)
                throw new IllegalArgumentException("unsupported_tensor_" + name);
        }
        long[] imageShape = ((ai.onnxruntime.TensorInfo)session.getInputInfo().get("image").getInfo()).getShape();
        long[] poseShape = ((ai.onnxruntime.TensorInfo)session.getInputInfo().get("pose").getInfo()).getShape();
        if (imageShape[2] != poseShape[2] || imageShape[3] != poseShape[3])
            throw new IllegalArgumentException("image_pose_size_mismatch");
        ai.onnxruntime.NodeInfo output = session.getOutputInfo().values().iterator().next();
        if (!(output.getInfo() instanceof ai.onnxruntime.TensorInfo))
            throw new IllegalArgumentException("output_not_tensor");
        ai.onnxruntime.TensorInfo tensor = (ai.onnxruntime.TensorInfo)output.getInfo();
        long[] shape = tensor.getShape();
        if (tensor.type != ai.onnxruntime.OnnxJavaType.FLOAT || shape.length != 4 ||
            shape[0] != 1 || shape[1] != 3 ||
            shape[2] != imageShape[2] || shape[3] != imageShape[3])
            throw new IllegalArgumentException("output_shape_mismatch");
    }

    private static int clamp(int x) { return Math.max(0, Math.min(255, x)); }
}
