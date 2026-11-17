package com.mobilei2v.encoder;
import android.net.Uri;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import java.io.File;
import java.io.FileNotFoundException;
import static org.junit.Assert.*;
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class ReferenceShareProviderTest {
    @Test public void onlyServesAppCreatedUuidImageCopies() throws Exception {
        File cache = RuntimeEnvironment.getApplication().getCacheDir();
        File folder = new File(cache, "karma_shares"); folder.mkdirs();
        String name = java.util.UUID.randomUUID().toString() + ".png";
        File copy = new File(folder, name); assertTrue(copy.createNewFile());
        assertEquals(copy.getCanonicalFile(), ReferenceShareProvider.resolve(cache, Uri.parse("content://app.karma.references/"+name)).getCanonicalFile());
        for (String path : new String[]{"../secret.png", "reference.png", "private/"+name, "", "..%2F"+name}) {
            try { ReferenceShareProvider.resolve(cache, Uri.parse("content://app.karma.references/"+path)); fail("Private path must be rejected"); }
            catch (FileNotFoundException expected) {}
        }
    }
}
