package com.mobilei2v.mnn;

/**
 * Executes the real pinned SD1.5 CLIP graph using two already-tokenized
 * 77-token sequences. Tokenization must be performed by a compatible
 * CLIP BPE tokenizer; this class never substitutes fabricated token IDs.
 */
public final class KarmaClipEncoder {
    private KarmaClipEncoder() {}

    public static final class Embeddings {
        public final float[] negative;
        public final float[] positive;
        private Embeddings(float[] negative, float[] positive) {
            this.negative = negative;
            this.positive = positive;
        }
    }

    public static Embeddings encode(String textEncoderPath, int[] negativeTokens,
                                    int[] positiveTokens) {
        if (textEncoderPath == null || textEncoderPath.isEmpty()
                || negativeTokens == null || positiveTokens == null
                || negativeTokens.length != 77 || positiveTokens.length != 77)
            throw new IllegalArgumentException("clip_requires_two_77_token_sequences");
        int[] batch = new int[154];
        System.arraycopy(negativeTokens, 0, batch, 0, 77);
        System.arraycopy(positiveTokens, 0, batch, 77, 77);
        try {
            if (!KarmaMnnBridge.loadGraph(textEncoderPath))
                throw new IllegalStateException("clip_load: " + KarmaMnnBridge.lastError());
            if (!KarmaMnnBridge.setIntInput("input_ids", batch))
                throw new IllegalStateException("clip_tokens: " + KarmaMnnBridge.lastError());
            if (!KarmaMnnBridge.runGraph())
                throw new IllegalStateException("clip_execute: " + KarmaMnnBridge.lastError());
            float[] all = KarmaMnnBridge.getFloatOutput("last_hidden_state");
            if (all == null || all.length != 2 * 77 * 768)
                throw new IllegalStateException("clip_embeddings_shape: " + KarmaMnnBridge.lastError());
            float[] negative = new float[77 * 768];
            float[] positive = new float[77 * 768];
            System.arraycopy(all, 0, negative, 0, negative.length);
            System.arraycopy(all, negative.length, positive, 0, positive.length);
            for (float value : all)
                if (!Float.isFinite(value))
                    throw new IllegalStateException("clip_non_finite_embedding");
            return new Embeddings(negative, positive);
        } finally {
            KarmaMnnBridge.release();
        }
    }
}
