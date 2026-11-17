package com.mobilei2v.encoder;
import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.ProgressBar;
import android.widget.Toast;
import java.lang.ref.WeakReference;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/** Android Sharesheet target; converts granted content into the existing private importer. */
public final class SharedImageReceiverActivity extends Activity {
    private static final Set<String> workers = ConcurrentHashMap.newKeySet();
    private static WeakReference<SharedImageReceiverActivity> current = new WeakReference<>(null);
    private String id = "";
    @Override protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        setContentView(new ProgressBar(this));
        Uri uri;
        try { uri = SharedImageInbox.imageUri(getIntent()); }
        catch (RuntimeException e) { uri = null; }
        if (uri == null) { Toast.makeText(this,"Partage refusé : une image content:// est nécessaire.",Toast.LENGTH_LONG).show(); finish(); return; }
        if (saved != null) {
            id = saved.getString("request", "");
            if (!id.equals(SharedImageInbox.current(this))) { openKarma(); return; }
            current = new WeakReference<>(this);
            if (!SharedImageInbox.peek(this).isEmpty()) { openKarma(); return; }
            if (workers.contains(id)) return;
        } else {
            String previous = SharedImageInbox.current(this);
            if (!previous.isEmpty() && SharedImageInbox.peek(this).isEmpty() && !workers.contains(previous))
                SharedImageInbox.acknowledge(this,previous); // A process killed during decode cannot trap future imports.
            id = SharedImageInbox.begin(this);
            if (id.isEmpty()) { Toast.makeText(this,"Une image attend déjà dans KARMA ONE. Termine son import avant un autre partage.",Toast.LENGTH_LONG).show(); openKarma(); return; }
            current = new WeakReference<>(this);
        }
        final String request = id;
        final Uri selected = uri;
        final android.content.Context context = getApplicationContext();
        workers.add(request);
        Handler handler = new Handler(Looper.getMainLooper());
        Runnable timeout = () -> {
            SharedImageInbox.complete(context,request,"error","Délai dépassé pendant la réception. Le projet est conservé. Réessaie depuis l'image originale.");
            finishReceiver(request);
        };
        handler.postDelayed(timeout,120000);
        new Thread(() -> {
            try {
                String path = ReferenceImageImporter.importImage(context, selected);
                // A timed-out result or a newer request cannot replace an existing result.
                if (SharedImageInbox.peek(context).isEmpty()) SharedImageInbox.complete(context,request,"selected",path);
            } catch (Exception | OutOfMemoryError e) {
                if (SharedImageInbox.peek(context).isEmpty()) SharedImageInbox.complete(context,request,"error","Réception image : " + e.getClass().getSimpleName() + ". Projet conservé.");
            } finally {
                handler.removeCallbacks(timeout); workers.remove(request);
                runOnUiThread(() -> finishReceiver(request));
            }
        },"KarmaSharedImage").start();
    }
    private static void finishReceiver(String request) {
        SharedImageReceiverActivity activity = current.get();
        if (activity != null && request.equals(activity.id)) activity.openKarma();
    }
    private void openKarma() {
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            startActivity(launch);
        }
        finish();
    }
    @Override protected void onSaveInstanceState(Bundle out) { out.putString("request",id); super.onSaveInstanceState(out); }
    @Override public void onBackPressed() { SharedImageInbox.acknowledge(this,id); finish(); }
}
