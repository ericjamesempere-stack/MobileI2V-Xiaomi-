package com.mobilei2v.encoder;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.ProviderInfo;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.GraphicsMode;
import org.robolectric.shadows.ShadowContentResolver;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileNotFoundException;
import static org.junit.Assert.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
public class ReferenceImageImporterTest {
    public static class Provider extends ContentProvider {
        File source;
        @Override public boolean onCreate() { return true; }
        @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
            return ParcelFileDescriptor.open(source, ParcelFileDescriptor.MODE_READ_ONLY);
        }
        @Override public String getType(Uri uri) { return "image/png"; }
        @Override public Cursor query(Uri u, String[] p, String s, String[] a, String sort) { return null; }
        @Override public Uri insert(Uri u, ContentValues v) { throw new UnsupportedOperationException(); }
        @Override public int delete(Uri u, String s, String[] a) { return 0; }
        @Override public int update(Uri u, ContentValues v, String s, String[] a) { return 0; }
    }
    private Uri photo(Context context, int width, int height) throws Exception {
        File file = File.createTempFile("camera_", ".png", context.getCacheDir());
        Bitmap image = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        image.eraseColor(Color.YELLOW);
        image.setPixel(0, 0, Color.RED);
        try (FileOutputStream output = new FileOutputStream(file)) { assertTrue(image.compress(Bitmap.CompressFormat.PNG, 100, output)); }
        image.recycle();
        Provider provider = new Provider();
        provider.source = file;
        ProviderInfo info = new ProviderInfo(); info.authority = "karma.test";
        provider.attachInfo(context, info);
        ShadowContentResolver.registerProviderInternal("karma.test", provider);
        return Uri.parse("content://karma.test/selected_photo");
    }
    @Test public void importsContentUriToReadablePngWithoutBroadStoragePermission() throws Exception {
        Context context = RuntimeEnvironment.getApplication();
        String path = ReferenceImageImporter.importImage(context, photo(context, 120, 80));
        Bitmap image = BitmapFactory.decodeFile(path);
        assertNotNull(image);
        assertEquals(120, image.getWidth()); assertEquals(80, image.getHeight());
        assertEquals(Color.YELLOW, image.getPixel(60, 40));
        assertEquals(Color.RED, image.getPixel(0, 0));
        assertTrue(new File(path).length() > 0);
        image.recycle();
    }
    @Test public void preservesSourceDetailAboveLegacyImportLimit() throws Exception {
        Context context = RuntimeEnvironment.getApplication();
        String path = ReferenceImageImporter.importImage(context, photo(context, 3200, 1600));
        Bitmap image = BitmapFactory.decodeFile(path);
        assertNotNull(image); assertEquals(3200, image.getWidth()); assertEquals(1600, image.getHeight());
        image.recycle();
    }
    @Test public void boundsVeryLargeCameraImagesBeforeAllocatingTheOutputBitmap() throws Exception {
        Context context = RuntimeEnvironment.getApplication();
        String path = ReferenceImageImporter.importImage(context, photo(context, 8192, 1024));
        Bitmap image = BitmapFactory.decodeFile(path);
        assertNotNull(image); assertEquals(4096, image.getWidth()); assertEquals(512, image.getHeight());
        image.recycle();
    }
}
