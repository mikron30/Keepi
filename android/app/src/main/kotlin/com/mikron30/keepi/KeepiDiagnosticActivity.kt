package com.mikron30.keepi

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.text.method.ScrollingMovementMethod
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class KeepiDiagnosticActivity : Activity() {
    private val prefs by lazy {
        getSharedPreferences("keepi_native_diagnostics", Context.MODE_PRIVATE)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installCrashRecorder()
        recordStage("native_diagnostic_before_super")
        super.onCreate(savedInstanceState)
        recordStage("native_diagnostic_after_super")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
            setBackgroundColor(Color.rgb(7, 17, 29))
        }

        root.addView(TextView(this).apply {
            text = "Keepi Android Diagnostics"
            textSize = 24f
            setTextColor(Color.WHITE)
        })

        root.addView(TextView(this).apply {
            text = "Native Android boot passed. Flutter has not started yet."
            textSize = 15f
            setTextColor(Color.LTGRAY)
            setPadding(0, 16, 0, 20)
        })

        val reportView = TextView(this).apply {
            text = buildNativeReport()
            textSize = 13f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.rgb(15, 24, 36))
            setPadding(20, 20, 20, 20)
            movementMethod = ScrollingMovementMethod()
        }

        root.addView(
            ScrollView(this).apply { addView(reportView) },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ),
        )

        root.addView(Button(this).apply {
            text = "Start Keepi / Flutter diagnostics"
            setOnClickListener {
                recordStage("launching_main_activity")
                startActivity(
                    Intent(
                        this@KeepiDiagnosticActivity,
                        MainActivity::class.java,
                    ),
                )
            }
        })

        root.addView(Button(this).apply {
            text = "Copy native report"
            setOnClickListener {
                val clipboard =
                    getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(
                    ClipData.newPlainText(
                        "Keepi native diagnostic",
                        buildNativeReport(),
                    ),
                )
            }
        })

        root.addView(Button(this).apply {
            text = "Clear saved crash and run again"
            setOnClickListener {
                prefs.edit()
                    .remove(KEY_CRASH)
                    .remove(KEY_LAST_STAGE)
                    .apply()
                recreate()
            }
        })

        setContentView(root)
    }

    private fun buildNativeReport(): String {
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val versionName = packageInfo.versionName ?: "unknown"
        val versionCode = if (Build.VERSION.SDK_INT >= 28) {
            packageInfo.longVersionCode.toString()
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toString()
        }

        val lastStage = prefs.getString(KEY_LAST_STAGE, "none") ?: "none"
        val crash = prefs.getString(KEY_CRASH, null)

        return buildString {
            appendLine("KEEPI NATIVE DIAGNOSTIC REPORT")
            appendLine("Package: $packageName")
            appendLine("Version: $versionName+$versionCode")
            appendLine("Android: ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})")
            appendLine("Device: ${Build.MANUFACTURER} ${Build.MODEL}")
            appendLine("ABI: ${Build.SUPPORTED_ABIS.joinToString()}")
            appendLine()
            appendLine("Native launcher: PASS")
            appendLine("Last startup stage: $lastStage")
            appendLine()
            if (crash == null) {
                appendLine("Saved uncaught crash: none")
            } else {
                appendLine("SAVED UNCAUGHT CRASH:")
                appendLine(crash)
            }
        }
    }

    private fun installCrashRecorder() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                prefs.edit()
                    .putString(
                        KEY_CRASH,
                        buildString {
                            appendLine("Thread: ${thread.name}")
                            appendLine(throwable.toString())
                            appendLine(android.util.Log.getStackTraceString(throwable))
                        },
                    )
                    .putString(KEY_LAST_STAGE, "uncaught_exception")
                    .commit()
            } catch (_: Throwable) {
            }

            previous?.uncaughtException(thread, throwable)
        }
    }

    private fun recordStage(stage: String) {
        prefs.edit().putString(KEY_LAST_STAGE, stage).apply()
    }

    companion object {
        const val PREFS = "keepi_native_diagnostics"
        const val KEY_LAST_STAGE = "last_stage"
        const val KEY_CRASH = "last_crash"
    }
}
