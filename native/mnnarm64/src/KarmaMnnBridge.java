package com.mobilei2v.mnn;

/**
 * Native MNN graph runner for Android arm64.
 * This is a low-level graph execution bridge, not yet a Stable Diffusion pipeline.
 * Requires a real MNN runtime and converted model graph(s).
 */
public final class KarmaMnnBridge {
    private KarmaMnnBridge() {}
    private static volatile boolean available;
    static {
        try {
            System.loadLibrary("MNN");
            System.loadLibrary("karma_mnn");
            available = true;
        } catch (UnsatisfiedLinkError e) {
            available = false;
        }
    }
    public static boolean isAvailable() { return available; }
    public static synchronized boolean loadGraph(String absolutePath) {
        return available && absolutePath != null && nativeLoadGraph(absolutePath);
    }
    public static synchronized boolean runGraph() { return available && nativeRunGraph(); }
    public static synchronized String lastError() {
        return available ? nativeLastError() : "mnn_native_library_missing";
    }
    public static synchronized void release() { if (available) nativeRelease(); }
    /**
     * One deterministic DDIM denoising step, requiring epsilon predicted by
     * a genuine MNN UNet graph. Null means invalid shapes or alpha schedule.
     * This method alone cannot generate an image.
     */
    public static synchronized float[] ddimStep(float[] latent, float[] epsilon,
                                                 float alphaT, float alphaPrev) {
        return available && latent != null && epsilon != null
                ? nativeDdimStep(latent, epsilon, alphaT, alphaPrev) : null;
    }
    private static native float[] nativeDdimStep(float[] latent, float[] epsilon,
                                                  float alphaT, float alphaPrev);
    public static synchronized boolean setFloatInput(String name, float[] values) {
        return available && name != null && values != null && nativeSetFloatInput(name, values);
    }
    public static synchronized float[] getFloatOutput(String name) {
        return available && name != null ? nativeGetFloatOutput(name) : null;
    }
    private static native boolean nativeSetFloatInput(String name, float[] values);
    private static native float[] nativeGetFloatOutput(String name);
    private static native boolean nativeLoadGraph(String path);
    private static native boolean nativeRunGraph();
    private static native String nativeLastError();
    private static native void nativeRelease();
}
