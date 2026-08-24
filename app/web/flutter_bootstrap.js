{{flutter_js}}
{{flutter_build_config}}

// Motor de dibujo (CanvasKit) servido localmente: la demo funciona
// completa sin depender del CDN de Google.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
