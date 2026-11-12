package vn.ccdauthau.cc_dau_thau

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "vn.ccdauthau/ad_config",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getAdConfig") {
                val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager.getApplicationInfo(
                        packageName,
                        PackageManager.ApplicationInfoFlags.of(
                            PackageManager.GET_META_DATA.toLong(),
                        ),
                    )
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.getApplicationInfo(
                        packageName,
                        PackageManager.GET_META_DATA,
                    )
                }
                val bannerUnitId =
                    appInfo.metaData?.getString("vn.ccdauthau.ADMOB_BANNER_ID")
                result.success(
                    mapOf("bannerUnitId" to bannerUnitId),
                )
            } else {
                result.notImplemented()
            }
        }
    }
}
