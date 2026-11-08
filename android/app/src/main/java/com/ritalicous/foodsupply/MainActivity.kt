package com.ritalicous.foodsupply

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ritalicious/updater")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls()
                    )
                    "openInstallSettings" -> {
                        val i = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(i)
                        result.success(true)
                    }
                    "install" -> {
                        try {
                            installApk(call.argument<String>("path")!!)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun installApk(path: String) {
        val file = File(path)
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        if (Build.VERSION.SDK_INT >= 31) {
            // Silent for later updates once this app has installed itself once.
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val id = installer.createSession(params)
        val session = installer.openSession(id)
        FileInputStream(file).use { input ->
            session.openWrite("update.apk", 0, file.length()).use { out ->
                input.copyTo(out)
                session.fsync(out)
            }
        }
        val intent = Intent(this, InstallReceiver::class.java)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 31) flags = flags or PendingIntent.FLAG_MUTABLE
        val pi = PendingIntent.getBroadcast(this, id, intent, flags)
        session.commit(pi.intentSender)
        session.close()
    }
}
