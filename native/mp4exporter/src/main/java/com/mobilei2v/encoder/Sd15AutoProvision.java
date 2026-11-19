package com.mobilei2v.encoder;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;
import java.util.HashSet;
import java.util.Set;

/** Public HTTPS release only; resumes downloads and verifies every file before activation. */
public final class Sd15AutoProvision {
    private static final String BASE = "https://github.com/ericjamesempere-stack/MobileI2V-Xiaomi-/releases/download/karma-sd15-mnn-v1/";
    private static volatile String state = "{\"state\":\"idle\"}";
    private static volatile boolean running = false;
    public static String status() { return state; }
    private static void report(String phase, String detail) {
        try { state = new JSONObject().put("state",phase).put("detail",detail).toString(); }
        catch(Exception ignored) {}
    }
    public static synchronized boolean start(Context context) {
        if (running) return false;
        ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkCapabilities nc = cm == null ? null : cm.getNetworkCapabilities(cm.getActiveNetwork());
        if (nc == null || !nc.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)) {
            report("waiting_wifi","Wi-Fi non facturé requis pour les modèles volumineux");
            return false;
        }
        running = true;
        new Thread(() -> {
            File root = new File(context.getFilesDir(),"models");
            File stage = new File(root,"sd15-auto-stage");
            File target = new File(root,"sd15");
            File backup = new File(root,"sd15-auto-backup");
            try {
                if (!root.isDirectory() && !root.mkdirs()) throw new IOException("models_directory");
                if (!stage.isDirectory() && !stage.mkdirs()) throw new IOException("stage_directory");
                report("catalog","Récupération du catalogue HTTPS");
                byte[] manifest = downloadSmall(BASE+"catalog.json",256*1024);
                JSONObject catalog = new JSONObject(new String(manifest,java.nio.charset.StandardCharsets.UTF_8));
                if (!"karma-sd15-public-v1".equals(catalog.getString("format"))) throw new IOException("catalog_format");
                JSONArray files = catalog.getJSONArray("files");
                Set<String> found = new HashSet<>();
                long total=0;
                for (int i=0;i<files.length();i++) {
                    JSONObject item=files.getJSONObject(i);
                    String name=item.getString("name");
                    if (!name.matches("(tokenizer\\.mtok|text_encoder\\.mnn(\\.weight)?|unet\\.mnn(\\.weight)?|vae_decoder\\.mnn(\\.weight)?)") || !found.add(name))
                        throw new IOException("catalog_filename");
                    long size=item.getLong("bytes");
                    if (size<1024 || size>2_000_000_000L || total+size>6_000_000_000L) throw new IOException("catalog_size");
                    total+=size;
                    String hash=item.getString("sha256");
                    if (!hash.matches("[a-fA-F0-9]{64}")) throw new IOException("catalog_sha");
                    File dest=new File(stage,name);
                    if (!dest.isFile() || dest.length()!=size || !hash.equalsIgnoreCase(sha256(dest))) {
                        report("downloading",name);
                        fetchResumable(BASE+name,dest,size);
                    }
                    report("verifying",name);
                    if (dest.length()!=size || !hash.equalsIgnoreCase(sha256(dest))) {
                        dest.delete();
                        throw new IOException("sha256_mismatch_"+name);
                    }
                }
                for (String name:new String[]{"tokenizer.mtok","text_encoder.mnn","unet.mnn","vae_decoder.mnn"})
                    if (!found.contains(name)) throw new IOException("missing_"+name);
                for (String graph:new String[]{"text_encoder.mnn","unet.mnn","vae_decoder.mnn"})
                    if (new File(stage,graph).length()<1024*1024 && !found.contains(graph+".weight"))
                        throw new IOException("missing_external_weight_"+graph);
                // Existing working installation is kept until the complete verified set is ready.
                delete(backup);
                if (target.exists() && !target.renameTo(backup)) throw new IOException("backup_failed");
                if (!stage.renameTo(target)) {
                    if (backup.exists()) backup.renameTo(target);
                    throw new IOException("activation_failed");
                }
                delete(backup);
                report("completed","Modèles téléchargés et SHA-256 vérifiés ; inférence à tester");
            } catch(Exception e) { report("error",e.getMessage()==null?e.getClass().getSimpleName():e.getMessage()); }
            finally { running=false; }
        },"KarmaSd15AutoProvision").start();
        return true;
    }
    private static byte[] downloadSmall(String url,int limit) throws IOException {
        HttpURLConnection c=connect(url,0);
        try (InputStream in=c.getInputStream(); ByteArrayOutputStream out=new ByteArrayOutputStream()) {
            byte[] b=new byte[8192]; int n;
            while((n=in.read(b))!=-1) { if(out.size()+n>limit) throw new IOException("catalog_too_large"); out.write(b,0,n); }
            return out.toByteArray();
        } finally { c.disconnect(); }
    }
    private static HttpURLConnection connect(String url,long offset) throws IOException {
        HttpURLConnection c=(HttpURLConnection)new URL(url).openConnection();
        c.setConnectTimeout(15000); c.setReadTimeout(30000);
        c.setInstanceFollowRedirects(true);
        if(offset>0)c.setRequestProperty("Range","bytes="+offset+"-");
        int code=c.getResponseCode();
        if(code!=200 && code!=206) { c.disconnect(); throw new IOException("HTTP_"+code); }
        if(!"https".equalsIgnoreCase(c.getURL().getProtocol())) {c.disconnect();throw new IOException("insecure_redirect");}
        return c;
    }
    private static void fetchResumable(String url,File dest,long expected) throws IOException {
        long offset=dest.isFile()?dest.length():0;
        if(offset>expected) {if(!dest.delete())throw new IOException("reset_partial");offset=0;}
        IOException last=null;
        for(int attempt=0;attempt<4;attempt++) {
            offset=dest.isFile()?dest.length():0;
            if(offset==expected)return;
            HttpURLConnection c=null;
            try {
                c=connect(url,offset);
                boolean append=offset>0 && c.getResponseCode()==206;
                if(append) {
                    String range=c.getHeaderField("Content-Range");
                    if(range==null || !range.startsWith("bytes "+offset+"-")) throw new IOException("invalid_content_range");
                }
                if(offset>0 && !append) offset=0;
                try(InputStream in=c.getInputStream(); OutputStream out=new BufferedOutputStream(new FileOutputStream(dest,append))) {
                    byte[] b=new byte[65536];int n;long count=offset;
                    while((n=in.read(b))!=-1) {
                        count+=n;
                        if(count>expected)throw new IOException("oversized_download");
                        out.write(b,0,n);
                    }
                }
                if(dest.length()==expected)return;
                last=new IOException("incomplete_download");
            } catch(IOException e) {last=e;}
            finally {if(c!=null)c.disconnect();}
        }
        throw last==null?new IOException("download_failed"):last;
    }
    private static String sha256(File file) throws Exception {
        MessageDigest md=MessageDigest.getInstance("SHA-256");
        try(InputStream in=new BufferedInputStream(new FileInputStream(file))) {
            byte[] b=new byte[65536];int n;while((n=in.read(b))!=-1)md.update(b,0,n);
        }
        StringBuilder out=new StringBuilder();
        for(byte b:md.digest())out.append(String.format(java.util.Locale.ROOT,"%02x",b&255));
        return out.toString();
    }
    private static void delete(File f) {
        if(!f.exists())return;
        if(f.isDirectory()){File[] children=f.listFiles();if(children!=null)for(File child:children)delete(child);}
        f.delete();
    }
}
