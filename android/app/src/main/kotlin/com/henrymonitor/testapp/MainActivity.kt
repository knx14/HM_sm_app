package com.henrymonitor.testapp

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.henrymonitor.testapp/google_maps_api_key"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getGoogleMapsApiKey") {
                try {
                    val apiKey = getGoogleMapsApiKey()
                    if (apiKey != null && apiKey.isNotEmpty()) {
                        if (BuildConfig.DEBUG) {
                            Log.d(TAG, "Google Maps API key is available")
                        }
                        result.success(apiKey)
                    } else {
                        Log.e(TAG, "API key is null or empty")
                        result.error("UNAVAILABLE", "Google Maps API key not found or empty", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to get API key: ${e.message}", e)
                    result.error("ERROR", "Failed to get API key: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getGoogleMapsApiKey(): String? {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, android.content.pm.PackageManager.GET_META_DATA)
            val bundle = appInfo.metaData
            bundle.getString("com.google.android.geo.API_KEY")
        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
            Log.e(TAG, "PackageManager.NameNotFoundException: ${e.message}", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "Exception in getGoogleMapsApiKey: ${e.message}", e)
            null
        }
    }
}
