package com.mobilei2v.encoder;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileNotFoundException;

/** Read-only, temporary grants for app-created image copies, never arbitrary private paths. */
public final class ReferenceShareProvider extends ContentProvider {
    @Override public boolean onCreate() { return true; }
    static File resolve(File cache, Uri uri) throws FileNotFoundException {
        String name = uri.getLastPathSegment();
        if (uri.getPathSegments().size() != 1 || name == null || !name.matches("[a-f0-9-]{36}\\.png"))
            throw new FileNotFoundException("Invalid shared image");
        File file = new File(new File(cache, "karma_shares"), name);
        try {
            if (!file.getCanonicalFile().getParentFile().equals(new File(cache, "karma_shares").getCanonicalFile()) || !file.isFile())
                throw new FileNotFoundException("Shared image unavailable");
        } catch (java.io.IOException e) { throw new FileNotFoundException("Shared image unavailable"); }
        return file;
    }
    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) throw new FileNotFoundException("Read only");
        return ParcelFileDescriptor.open(resolve(getContext().getCacheDir(), uri), ParcelFileDescriptor.MODE_READ_ONLY);
    }
    @Override public String getType(Uri uri) { return "image/png"; }
    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sort) {
        try {
            File file = resolve(getContext().getCacheDir(), uri);
            String[] columns = projection == null ? new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE} : projection;
            MatrixCursor cursor = new MatrixCursor(columns);
            Object[] values = new Object[columns.length];
            for (int i=0; i<columns.length; i++) {
                if (OpenableColumns.DISPLAY_NAME.equals(columns[i])) values[i] = "KARMA_reference.png";
                if (OpenableColumns.SIZE.equals(columns[i])) values[i] = file.length();
            }
            cursor.addRow(values); return cursor;
        } catch (FileNotFoundException e) { return null; }
    }
    @Override public Uri insert(Uri u, ContentValues v) { throw new UnsupportedOperationException("Read only"); }
    @Override public int update(Uri u, ContentValues v, String s, String[] a) { throw new UnsupportedOperationException("Read only"); }
    @Override public int delete(Uri u, String s, String[] a) { throw new UnsupportedOperationException("Read only"); }
}
