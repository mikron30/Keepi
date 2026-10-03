package com.mikron30.keepi

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val prefs by lazy {
        getSharedPreferences(
            KeepiDiagnosticActivity.PREFS,
            Context.MODE_PRIVATE,
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        recordStage("main_activity_onCreate_before_super")
        super.onCreate(savedInstanceState)
        recordStage("main_activity_onCreate_after_super")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        recordStage("configure_flutter_engine_before_super")
        super.configureFlutterEngine(flutterEngine)
        recordStage("configure_flutter_engine_after_super")
    }

    override fun onPostResume() {
        super.onPostResume()
        recordStage("main_activity_onPostResume")
    }

    private fun recordStage(stage: String) {
        prefs.edit()
            .putString(KeepiDiagnosticActivity.KEY_LAST_STAGE, stage)
            .apply()
    }
}
