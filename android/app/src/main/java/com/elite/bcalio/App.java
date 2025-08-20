package com.elite.bcalio;

import android.app.Application;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;

public class App extends Application {
  public static final String ENGINE_ID = "main_engine";

  @Override
  public void onCreate() {
    super.onCreate();

    // ⚡️ Pré-démarre l’engine Flutter pour réduire le cold start
    FlutterEngine engine = new FlutterEngine(this);
    engine.getDartExecutor().executeDartEntrypoint(
        DartExecutor.DartEntrypoint.createDefault()
    );
    FlutterEngineCache.getInstance().put(ENGINE_ID, engine);
  }
}
