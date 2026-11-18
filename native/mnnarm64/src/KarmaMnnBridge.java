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
    private static native boolean nativeLoadGraph(String path);
    private static native boolean nativeRunGraph();
    private static native String nativeLastError();
    private static native void nativeRelease();
}
