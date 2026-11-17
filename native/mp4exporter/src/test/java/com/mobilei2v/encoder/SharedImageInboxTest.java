package com.mobilei2v.encoder;
import android.content.Context;
import android.content.Intent;
import android.content.ClipData;
import android.net.Uri;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import static org.junit.Assert.*;
@RunWith(RobolectricTestRunner.class)
@Config(sdk=34)
public class SharedImageInboxTest {
    @Test public void acceptsGrantedSingleContentImageOnly() {
        Uri image=Uri.parse("content://sender/image/1");
        Intent intent=new Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM,image).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        assertEquals(image,SharedImageInbox.imageUri(intent));
        intent.removeExtra(Intent.EXTRA_STREAM);intent.setClipData(ClipData.newRawUri("image",image));
        assertEquals(image,SharedImageInbox.imageUri(intent));
        assertNull(SharedImageInbox.imageUri(new Intent(Intent.ACTION_SEND).setType("image/jpeg").putExtra(Intent.EXTRA_STREAM,Uri.parse("file:///data/private/image.png"))));
        assertNull(SharedImageInbox.imageUri(new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_STREAM,image)));
        assertNull(SharedImageInbox.imageUri(new Intent(Intent.ACTION_SEND_MULTIPLE).setType("image/png")));
        assertNull(SharedImageInbox.imageUri(new Intent(Intent.ACTION_VIEW).setType("image/png").setData(image)));
    }
    @Test public void survivesRecreationAndNeverOverwritesPendingOrAcknowledgesWrongRequest() throws Exception {
        Context context=RuntimeEnvironment.getApplication();
        String id=SharedImageInbox.begin(context);assertFalse(id.isEmpty());
        assertEquals("",SharedImageInbox.begin(context));
        SharedImageInbox.complete(context,id,"selected","/private/import.png");
        SharedImageInbox.complete(context,id,"error","stale timeout");
        assertEquals("selected",new JSONObject(SharedImageInbox.peek(context)).getString("state"));
        SharedImageInbox.acknowledge(context,"wrong-id");assertFalse(SharedImageInbox.peek(context).isEmpty());
        SharedImageInbox.acknowledge(context,id);assertEquals("",SharedImageInbox.peek(context));
        String next=SharedImageInbox.begin(context);assertNotEquals(id,next);
        SharedImageInbox.complete(context,id,"selected","stale.png");assertEquals("",SharedImageInbox.peek(context));
        SharedImageInbox.acknowledge(context,next);
    }
    @Test public void reportsInterruptedDecodeAfterProcessTimeout() throws Exception {
        Context context=RuntimeEnvironment.getApplication();
        String id=SharedImageInbox.begin(context);
        context.getSharedPreferences("karma_shared_image_v60",0).edit().putLong("started_at",System.currentTimeMillis()-121000).commit();
        assertEquals("error",new JSONObject(SharedImageInbox.peek(context)).getString("state"));
        SharedImageInbox.acknowledge(context,id);
        assertEquals("",SharedImageInbox.peek(context));
    }

}
