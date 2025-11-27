package com.ishankumar.maizebus

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState);
        window.attributes.preferredDisplayModeId =
            window.windowManager.defaultDisplay.supportedModes
                .maxByOrNull { it.refreshRate }?.modeId ?: 0

    }
}
