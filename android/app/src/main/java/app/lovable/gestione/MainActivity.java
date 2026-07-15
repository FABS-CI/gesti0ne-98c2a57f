package app.lovable.gestione;

import android.Manifest;
import android.content.ContentValues;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.widget.Toast;

import androidx.core.app.ActivityCompat;

import com.getcapacitor.BridgeActivity;

import java.io.OutputStream;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Runtime permission notifications (Android 13+)
        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this,
                        new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1001);
            }
        }

        // Pont JS pour enregistrer un fichier (contourne les blobs non
        // téléchargeables par la WebView Android).
        this.bridge.getWebView().addJavascriptInterface(
                new FileSaver(this), "AndroidFileSaver");
    }

    public static class FileSaver {
        private final MainActivity ctx;

        FileSaver(MainActivity ctx) {
            this.ctx = ctx;
        }

        @JavascriptInterface
        public void saveBase64(String filename, String base64, String mime) {
            try {
                byte[] bytes = Base64.decode(base64, Base64.DEFAULT);
                Uri uri;
                if (Build.VERSION.SDK_INT >= 29) {
                    ContentValues values = new ContentValues();
                    values.put(MediaStore.Downloads.DISPLAY_NAME, filename);
                    values.put(MediaStore.Downloads.MIME_TYPE,
                            mime == null || mime.isEmpty() ? "application/pdf" : mime);
                    values.put(MediaStore.Downloads.IS_PENDING, 1);
                    uri = ctx.getContentResolver().insert(
                            MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
                    if (uri == null) return;
                    try (OutputStream os = ctx.getContentResolver().openOutputStream(uri)) {
                        if (os != null) os.write(bytes);
                    }
                    values.clear();
                    values.put(MediaStore.Downloads.IS_PENDING, 0);
                    ctx.getContentResolver().update(uri, values, null, null);
                } else {
                    java.io.File dir = Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DOWNLOADS);
                    if (!dir.exists()) dir.mkdirs();
                    java.io.File file = new java.io.File(dir, filename);
                    try (java.io.FileOutputStream fos = new java.io.FileOutputStream(file)) {
                        fos.write(bytes);
                    }
                }
                ctx.runOnUiThread(() -> Toast.makeText(ctx,
                        "Enregistré dans Téléchargements : " + filename,
                        Toast.LENGTH_LONG).show());
            } catch (Exception e) {
                ctx.runOnUiThread(() -> Toast.makeText(ctx,
                        "Échec téléchargement : " + e.getMessage(),
                        Toast.LENGTH_LONG).show());
            }
        }
    }
}
