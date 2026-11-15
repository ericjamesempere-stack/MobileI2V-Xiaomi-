package com.mobilei2v.encoder;

import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import java.io.File;
import java.nio.ByteBuffer;

/** H.264 MP4 encoder for RGBA8888 frames, using a YUV420 planar input codec. */
public final class AvcMp4Encoder {
    private MediaCodec codec;
    private MediaMuxer muxer;
    private int width, height, fps, frames, track = -1;
    private boolean muxerStarted;
    private final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
    private String output;

    public void begin(String path, int w, int h, int frameRate) throws Exception {
        if (codec != null) throw new IllegalStateException("already encoding");
        if (w <= 0 || h <= 0 || (w & 1) != 0 || (h & 1) != 0 || frameRate <= 0)
            throw new IllegalArgumentException("dimensions must be positive and even");
        width = w; height = h; fps = frameRate; frames = 0; track = -1; muxerStarted = false;
        output = path;
        File parent = new File(path).getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs())
            throw new IllegalStateException("output directory unavailable");
        MediaFormat format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar);
        format.setInteger(MediaFormat.KEY_BIT_RATE, Math.max(1_000_000, w * h * frameRate / 4));
        format.setInteger(MediaFormat.KEY_FRAME_RATE, frameRate);
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
        try {
            codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
            boolean planarSupported = false;
            for (int color : codec.getCodecInfo().getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC).colorFormats) {
                if (color == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar) {
                    planarSupported = true;
                    break;
                }
            }
            if (!planarSupported) throw new IllegalStateException("device AVC codec does not support planar YUV420");
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            codec.start();
            muxer = new MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        } catch (Exception ex) {
            abort();
            throw ex;
        }
    }

    public void pushFrame(byte[] rgba) throws Exception {
        if (codec == null) throw new IllegalStateException("encoder not started");
        if (rgba == null || rgba.length != width * height * 4)
            throw new IllegalArgumentException("expected RGBA8888 frame");
        int input = codec.dequeueInputBuffer(10_000_000);
        if (input < 0) throw new IllegalStateException("encoder input timeout");
        ByteBuffer buffer = codec.getInputBuffer(input);
        if (buffer == null) throw new IllegalStateException("encoder input missing");
        buffer.clear();
        int ySize = width * height;
        byte[] yuv = new byte[ySize * 3 / 2];
        // I420 planes: Y, U, V. Requires a codec that advertises planar YUV420.
        int uvWidth = width / 2;
        for (int row = 0; row < height; row++) {
            for (int col = 0; col < width; col++) {
                int p = (row * width + col) * 4;
                int r = rgba[p] & 255, g = rgba[p + 1] & 255, b = rgba[p + 2] & 255;
                int y = clamp(((66 * r + 129 * g + 25 * b + 128) >> 8) + 16);
                yuv[row * width + col] = (byte)y;
                if ((row & 1) == 0 && (col & 1) == 0) {
                    int uv = (row / 2) * uvWidth + col / 2;
                    yuv[ySize + uv] = (byte)clamp(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128);
                    yuv[ySize + ySize / 4 + uv] = (byte)clamp(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128);
                }
            }
        }
        if (buffer.remaining() < yuv.length) throw new IllegalStateException("encoder input buffer too small");
        buffer.put(yuv);
        codec.queueInputBuffer(input, 0, yuv.length, frames * 1_000_000L / fps, 0);
        frames++;
        drain(false);
    }

    public String finish() throws Exception {
        if (codec == null) throw new IllegalStateException("encoder not started");
        try {
            int input = codec.dequeueInputBuffer(10_000_000);
            if (input < 0) throw new IllegalStateException("encoder EOS input timeout");
            codec.queueInputBuffer(input, 0, 0, frames * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
            drain(true);
            if (!muxerStarted || frames == 0) throw new IllegalStateException("no video track or frames");
            return output;
        } finally {
            abort();
        }
    }

    private void drain(boolean end) throws Exception {
        int idle = 0;
        while (true) {
            int index = codec.dequeueOutputBuffer(info, end ? 10_000 : 0);
            if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                if (muxerStarted) throw new IllegalStateException("format changed twice");
                track = muxer.addTrack(codec.getOutputFormat());
                muxer.start();
                muxerStarted = true;
            } else if (index >= 0) {
                ByteBuffer data = codec.getOutputBuffer(index);
                if (data == null) throw new IllegalStateException("encoder output missing");
                if ((info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) info.size = 0;
                if (info.size > 0) {
                    if (!muxerStarted) throw new IllegalStateException("muxer not started");
                    data.position(info.offset);
                    data.limit(info.offset + info.size);
                    muxer.writeSampleData(track, data, info);
                }
                boolean eos = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
                codec.releaseOutputBuffer(index, false);
                if (eos) return;
                idle = 0;
            } else if (index == MediaCodec.INFO_TRY_AGAIN_LATER) {
                if (!end) return;
                if (++idle > 1000) throw new IllegalStateException("encoder EOS timeout");
            }
        }
    }

    public void abort() {
        if (codec != null) {
            try { codec.stop(); } catch (Exception ignored) {}
            codec.release();
            codec = null;
        }
        if (muxer != null) {
            if (muxerStarted) try { muxer.stop(); } catch (Exception ignored) {}
            muxer.release();
            muxer = null;
        }
        muxerStarted = false;
    }

    private static int clamp(int n) { return Math.max(0, Math.min(255, n)); }
}
