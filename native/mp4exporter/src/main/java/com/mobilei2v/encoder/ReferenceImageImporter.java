package com.mobilei2v.encoder;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageDecoder;
import android.net.Uri;
import android.os.Build;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

/** Convert a granted Android document URI to a bounded PNG the engine can read. */
public final class ReferenceImageImporter {
    private static final int MAX_SIDE = 4096;
    private ReferenceImageImporter() {}
    public static String importImage(Context context, Uri uri) throws Exception {
        if (context == null || uri == null) throw new IllegalArgumentException("Missing image selection");
        Bitmap bitmap;
        if (Build.VERSION.SDK_INT >= 28) {
            bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.getContentResolver(), uri),
                (decoder, info, source) -> {
                    int w = info.getSize().getWidth(), h = info.getSize().getHeight();
                    double scale = Math.min(1.0, (double) MAX_SIDE / Math.max(w, h));
                    decoder.setTargetSize(Math.max(1, (int)Math.round(w * scale)),
                                          Math.max(1, (int)Math.round(h * scale)));
                    decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE);
                });
        } else {
            BitmapFactory.Options bounds = new BitmapFactory.Options();
            bounds.inJustDecodeBounds = true;
            try (InputStream input = context.getContentResolver().openInputStream(uri)) {
                BitmapFactory.decodeStream(input, null, bounds);
            }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw new IllegalArgumentException("Unreadable image");
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inSampleSize = 1;
            while (Math.max(bounds.outWidth, bounds.outHeight) / options.inSampleSize > MAX_SIDE) options.inSampleSize *= 2;
            try (InputStream input = context.getContentResolver().openInputStream(uri)) {
                bitmap = BitmapFactory.decodeStream(input, null, options);
            }
        }
        if (bitmap == null) throw new IllegalArgumentException("Unsupported or unreadable image");
        File folder = new File(context.getFilesDir(), "reference_imports");
        if (!folder.isDirectory() && !folder.mkdirs()) throw new IllegalStateException("Cannot create image folder");
        File output = File.createTempFile("reference_", ".png", folder);
        boolean complete = false;
        try (FileOutputStream stream = new FileOutputStream(output)) {
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) throw new IllegalStateException("PNG conversion failed");
            stream.flush();
            complete = true;
            return output.getAbsolutePath();
        } finally {
            bitmap.recycle();
            if (!complete) output.delete();
        }
    }
}
