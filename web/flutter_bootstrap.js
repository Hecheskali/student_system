{{flutter_js}}
{{flutter_build_config}}

// Keep Flutter Web fully self-hosted so startup doesn't depend on the Google CDN.
_flutter.buildConfig.useLocalCanvasKit = true;

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
