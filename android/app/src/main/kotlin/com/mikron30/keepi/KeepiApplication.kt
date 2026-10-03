package com.mikron30.keepi

import android.app.Application
import android.content.Context
import android.util.Log

class KeepiApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)

        val prefs = getSharedPreferences(
            KeepiDiagnosticActivity.PREFS,
            Context.MODE_PRIVATE,
        )

        val previous = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                prefs.edit()
                    .putString(
                        KeepiDiagnosticActivity.KEY_CRASH,
                        buildString {
                            appendLine("Thread: ${thread.name}")
                            appendLine(throwable.toString())
                            appendLine(Log.getStackTraceString(throwable))
                        },
                    )
                    .putString(
                        KeepiDiagnosticActivity.KEY_LAST_STAGE,
                        "application_uncaught_exception",
                    )
                    .commit()
            } catch (_: Throwable) {
            }

            previous?.uncaughtException(thread, throwable)
        }

        prefs.edit()
            .putString(
                KeepiDiagnosticActivity.KEY_LAST_STAGE,
                "application_attachBaseContext",
            )
            .commit()
    }

    override fun onCreate() {
        super.onCreate()

        getSharedPreferences(
            KeepiDiagnosticActivity.PREFS,
            Context.MODE_PRIVATE,
        ).edit()
            .putString(
                KeepiDiagnosticActivity.KEY_LAST_STAGE,
                "application_onCreate",
            )
            .commit()
    }
}
