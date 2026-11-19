package com.mobilei2v.mnn;

import android.graphics.Bitmap;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.Random;

/**
 * Real MNN UNet -> DDIM -> VAE execution, with explicitly supplied CLIP embeddings.
 * Not text-to-image yet: caller must tokenize prompt and execute a compatible text encoder.
 * Models MUST expose the exact named float32 tensors documented below. No mock images.
 * Run on a background worker thread, never the Android UI thread.
 */
public final class KarmaSdInference {
    private KarmaSdInference() {}

    public static final class Config {
        public String unetPath, vaePath, outputPng;
        public String latentInput = "sample", timestepInput = "timestep";
        public String contextInput = "encoder_hidden_states", noiseOutput = "out_sample";
        public String vaeInput = "latent_sample", vaeOutput = "sample";
        public int width = 512, height = 512;
        public int steps = 20;
        public long seed = 1L;
        public float guidance = 7.5f;
        public float vaeScaling = 0.18215f;
        // Full training alpha_cumprod (usually 1000 entries) from the matching scheduler.
        public float[] alphasCumprod;
        public int[] timesteps; // descending model training timesteps, one per inference step
    }

    private static void require(boolean ok, String message) {
        if (!ok) throw new IllegalStateException(message + ": " + KarmaMnnBridge.lastError());
    }

    /**
     * @param positiveEmbeddings real CLIP text encoder output, flattened float32
     * @param negativeEmbeddings real unconditional/negative CLIP output, same shape
     */
    public static File generate(Config cfg, float[] positiveEmbeddings,
                                float[] negativeEmbeddings) throws IOException {
        if (cfg == null || positiveEmbeddings == null || negativeEmbeddings == null
                || positiveEmbeddings.length == 0
                || positiveEmbeddings.length != negativeEmbeddings.length
                || cfg.unetPath == null || cfg.vaePath == null || cfg.outputPng == null
                || cfg.width < 64 || cfg.height < 64 || cfg.width > 1024 || cfg.height > 1024
                || cfg.width % 8 != 0 || cfg.height % 8 != 0
                || cfg.steps < 1 || cfg.steps > 100
                || !Float.isFinite(cfg.guidance) || cfg.guidance < 0 || cfg.guidance > 30
                || !Float.isFinite(cfg.vaeScaling) || cfg.vaeScaling <= 0
                || cfg.timesteps == null || cfg.timesteps.length != cfg.steps
                || cfg.alphasCumprod == null || cfg.alphasCumprod.length < 2)
            throw new IllegalArgumentException("invalid_sd_configuration");
        for (float a : cfg.alphasCumprod)
            if (!Float.isFinite(a) || a <= 0 || a > 1)
                throw new IllegalArgumentException("invalid_alpha_schedule");
        for (int i = 0; i < cfg.steps; ++i) {
            int t = cfg.timesteps[i];
            if (t < 0 || t >= cfg.alphasCumprod.length
                    || (i > 0 && t >= cfg.timesteps[i - 1]))
                throw new IllegalArgumentException("invalid_timestep_sequence");
        }
        // The pinned SD15 ONNX export uses fixed batch=2 for CLIP and UNet,
        // while the VAE decoder uses batch=1. Fail closed rather than
        // silently supplying batch=1 tensors to a batch=2 UNet.
        if (cfg.width != 512 || cfg.height != 512)
            throw new IllegalArgumentException("sd15_export_requires_512x512");
        if (positiveEmbeddings.length != 77 * 768
                || negativeEmbeddings.length != 77 * 768)
            throw new IllegalArgumentException("sd15_clip_embedding_shape_mismatch");
        int latentCount = 4 * (cfg.width / 8) * (cfg.height / 8);
        float[] latent = new float[latentCount];
        Random random = new Random(cfg.seed);
        for (int i = 0; i < latentCount; i++) latent[i] = (float) random.nextGaussian();
        try {
            require(KarmaMnnBridge.loadGraph(cfg.unetPath), "UNet graph load");
            for (int i = 0; i < cfg.steps; ++i) {
                int t = cfg.timesteps[i];
                // Exported UNet has fixed batch=2: [negative, positive].
                float[] batchLatent = new float[latentCount * 2];
                System.arraycopy(latent, 0, batchLatent, 0, latentCount);
                System.arraycopy(latent, 0, batchLatent, latentCount, latentCount);
                float[] batchContext = new float[2 * 77 * 768];
                System.arraycopy(negativeEmbeddings, 0, batchContext, 0, 77 * 768);
                System.arraycopy(positiveEmbeddings, 0, batchContext, 77 * 768, 77 * 768);
                float[] batchTimestep = { (float) t, (float) t };
                require(KarmaMnnBridge.setFloatInput(cfg.latentInput, batchLatent), "UNet batch latent");
                require(KarmaMnnBridge.setFloatInput(cfg.timestepInput, batchTimestep), "UNet batch timestep");
                require(KarmaMnnBridge.setFloatInput(cfg.contextInput, batchContext), "UNet batch context");
                require(KarmaMnnBridge.runGraph(), "UNet batched inference");
                float[] noiseBatch = KarmaMnnBridge.getFloatOutput(cfg.noiseOutput);
                require(noiseBatch != null && noiseBatch.length == 2 * latentCount,
                        "UNet batched output shape");
                float[] unconditional = new float[latentCount];
                for (int j = 0; j < latentCount; ++j)
                    unconditional[j] = noiseBatch[j] + cfg.guidance
                            * (noiseBatch[latentCount + j] - noiseBatch[j]);
                float previousAlpha = i + 1 == cfg.steps ? 1.0f
                        : cfg.alphasCumprod[cfg.timesteps[i + 1]];
                float[] next = KarmaMnnBridge.ddimStep(
                        latent, unconditional, cfg.alphasCumprod[t], previousAlpha);
                require(next != null && next.length == latentCount, "DDIM step");
                latent = next;
            }
            KarmaMnnBridge.release();
            require(KarmaMnnBridge.loadGraph(cfg.vaePath), "VAE graph load");
            for (int i = 0; i < latentCount; ++i) latent[i] /= cfg.vaeScaling;
            require(KarmaMnnBridge.setFloatInput(cfg.vaeInput, latent), "VAE latent input");
            require(KarmaMnnBridge.runGraph(), "VAE inference");
            float[] rgb = KarmaMnnBridge.getFloatOutput(cfg.vaeOutput);
            int pixels = cfg.width * cfg.height;
            require(rgb != null && rgb.length == pixels * 3, "VAE RGB output shape");
            // Expected output is float32 NCHW RGB, [-1,1]; no silent NHWC conversion.
            int[] argb = new int[pixels];
            for (int p = 0; p < pixels; ++p) {
                int r = channel(rgb[p]);
                int g = channel(rgb[p + pixels]);
                int b = channel(rgb[p + 2 * pixels]);
                argb[p] = 0xff000000 | (r << 16) | (g << 8) | b;
            }
            Bitmap bitmap = Bitmap.createBitmap(cfg.width, cfg.height, Bitmap.Config.ARGB_8888);
            try {
                bitmap.setPixels(argb, 0, cfg.width, 0, 0, cfg.width, cfg.height);
                File output = new File(cfg.outputPng);
                File parent = output.getParentFile();
                if (parent == null || !parent.isDirectory())
                    throw new IOException("output_directory_missing");
                try (FileOutputStream stream = new FileOutputStream(output)) {
                    if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream))
                        throw new IOException("png_encoding_failed");
                }
                return output;
            } finally {
                bitmap.recycle();
            }
        } finally {
            KarmaMnnBridge.release();
        }
    }

    private static int channel(float x) {
        if (!Float.isFinite(x)) throw new IllegalStateException("non_finite_vae_output");
        return Math.max(0, Math.min(255, Math.round((x * 0.5f + 0.5f) * 255f)));
    }
}
