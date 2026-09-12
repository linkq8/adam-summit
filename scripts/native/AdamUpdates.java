package com.godot.game;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import androidx.core.content.FileProvider;
import androidx.annotation.Keep;
import java.io.File;

@Keep
public final class AdamUpdates {
    @Keep
    public static String install(Activity activity, String path) {
        try {
            File file = new File(path).getCanonicalFile();
            if (!file.getName().equals("adam-update.apk") || !file.getPath().startsWith(activity.getFilesDir().getCanonicalPath() + File.separator))
                return "invalid_file";
            if (!file.isFile()) return "missing_file";
            if (Build.VERSION.SDK_INT >= 26 && !activity.getPackageManager().canRequestPackageInstalls()) {
                activity.runOnUiThread(() -> activity.startActivity(new Intent("android.settings.MANAGE_UNKNOWN_APP_SOURCES", Uri.parse("package:" + activity.getPackageName()))));
                return "permission";
            }
            Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".updates", file);
            Intent intent = new Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            if (intent.resolveActivity(activity.getPackageManager()) == null) return "no_installer";
            activity.runOnUiThread(() -> activity.startActivity(intent));
            return "opened";
        } catch (Exception e) { return "install_error"; }
    }
}
