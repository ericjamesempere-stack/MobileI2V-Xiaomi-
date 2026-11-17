package com.mobilei2v.encoder;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ProviderInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.net.Uri;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.GraphicsMode;
import org.robolectric.shadows.ShadowContentResolver;
import java.io.File;
import java.io.FileOutputStream;
import static org.junit.Assert.*;
/** Actual PNG/worker/private-file integration, simulated Android framework, not a physical phone. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk=34)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
public class SharedImageReceiverTest {
    @Test public void receivesContentImageAndCopiesBeforeReturningToGodot() throws Exception {
        Context context=RuntimeEnvironment.getApplication();
        File source=File.createTempFile("received_", ".png",context.getCacheDir());
        Bitmap art=Bitmap.createBitmap(512,320,Bitmap.Config.ARGB_8888);art.eraseColor(Color.YELLOW);art.setPixel(0,0,Color.RED);
        try(FileOutputStream out=new FileOutputStream(source)){assertTrue(art.compress(Bitmap.CompressFormat.PNG,100,out));} art.recycle();
        ReferenceImageImporterTest.Provider provider=new ReferenceImageImporterTest.Provider();provider.source=source;
        ProviderInfo info=new ProviderInfo();info.authority="karma.receive.test";provider.attachInfo(context,info);
        ShadowContentResolver.registerProviderInternal(info.authority,provider);
        Intent intent=new Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM,Uri.parse("content://karma.receive.test/image")).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        Robolectric.buildActivity(SharedImageReceiverActivity.class,intent).setup();
        long deadline=System.nanoTime()+5_000_000_000L;
        while(SharedImageInbox.peek(context).isEmpty() && System.nanoTime()<deadline) Thread.sleep(10);
        JSONObject result=new JSONObject(SharedImageInbox.peek(context));
        assertEquals("selected",result.getString("state"));
        File target=new File(result.getString("value"));assertTrue(target.getCanonicalPath().startsWith(context.getFilesDir().getCanonicalPath()+File.separator));
        Bitmap decoded=BitmapFactory.decodeFile(target.getPath());assertNotNull(decoded);assertEquals(512,decoded.getWidth());assertEquals(320,decoded.getHeight());assertEquals(Color.RED,decoded.getPixel(0,0));decoded.recycle();
        assertTrue(source.exists()); // Sender's file is never modified or removed.
        SharedImageInbox.acknowledge(context,result.getString("id"));
    }
}
