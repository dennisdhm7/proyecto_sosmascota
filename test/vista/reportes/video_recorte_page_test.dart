import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:provider/provider.dart';
import 'package:sos_mascotas/vista/reportes/video_recorte_page.dart';
import 'package:sos_mascotas/vistamodelo/reportes/reporte_vm.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// =========================================================
/// FAKE ViewModel (sin Mockito)
/// =========================================================
class ReporteMascotaVMFake extends ChangeNotifier implements ReporteMascotaVM {
  bool subirVideoCalled = false;
  bool agregarVideoCalled = false;

  File? archivoSubido;
  String? urlAgregada;

  @override
  Future<String> subirVideo(File video) async {
    subirVideoCalled = true;
    archivoSubido = video;
    return "http://firebase.url/video.mp4";
  }

  @override
  void agregarVideo(String url) {
    agregarVideoCalled = true;
    urlAgregada = url;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// =========================================================
/// Fake del video player
/// =========================================================
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<void> init() async {} // ✅ Correcto

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> dispose(int textureId) async {}

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 5),
      size: const Size(200, 200),
      rotationCorrection: 0,
    ),
  );
}

// Fake Trimmer para pruebas: llama al callback onSave inmediatamente cuando se pide guardar
class FakeTrimmer extends Trimmer {
  @override
  Future<void> loadVideo({required File videoFile}) async {}

  @override
  Future<void> saveTrimmedVideo({
    required double startValue,
    required double endValue,
    required dynamic Function(String?) onSave,
    OutputType? outputType,
    int? fpsGIF,
    int? qualityGIF,
    int? scaleGIF,
    StorageDir? storageDir,
    String? videoFileName,
    String? videoFolderName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 60));
    onSave('/tmp/video_recortado_output.mp4');
  }
}

void main() {
  late ReporteMascotaVMFake fakeVM;
  late File fakeFile;

  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  setUp(() {
    fakeVM = ReporteMascotaVMFake();
    fakeFile = File("test_video.mp4");

    // Fake del paquete video_trimmer
    const channel = MethodChannel("video_trimmer");
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final m = call.method.toLowerCase();
          if (m.contains('load')) return null;

          if (m.contains('save')) {
            await Future.delayed(const Duration(milliseconds: 60));
            return "/tmp/video_recortado_output.mp4";
          }

          return null;
        });
  });

  // NOTE: usamos un FakeTrimmer top-level (definido arriba) para inyección cuando haga falta

  Future<void> cargarPantalla(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ReporteMascotaVM>(
          create: (_) => fakeVM,
          builder: (context, _) =>
              VideoRecortePage(videoFile: fakeFile, trimmer: FakeTrimmer()),
        ),
      ),
    );

    // Asegurar inicialización del video
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  // =========================================================
  // TEST DEL FLUJO COMPLETO
  // =========================================================
  testWidgets("🟣 Flujo Completo: Recortar → Guardar → Subir → Cerrar", (
    tester,
  ) async {
    await cargarPantalla(tester);

    // Buscar botón
    final btn = find.text("Guardar clip (≤10s)");
    expect(btn, findsOneWidget);

    // Tap
    await tester.tap(btn);
    await tester.pump();

    // loader
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // completar recorte + subida
    await tester.pump(const Duration(seconds: 2));

    // Evitar `pumpAndSettle()` directo (puede bloquear por streams/animaciones).
    // En su lugar, bombeamos de forma controlada hasta que la subida ocurra
    // o se alcance un timeout razonable.
    const int maxMillis = 5000;
    int elapsed = 0;
    while (!fakeVM.subirVideoCalled && elapsed < maxMillis) {
      await tester.pump(const Duration(milliseconds: 100));
      elapsed += 100;
    }

    // permitir que las animaciones remanentes avancen brevemente (no esperar a que terminen)
    await tester.pump(const Duration(milliseconds: 200));

    // Verificaciones
    expect(fakeVM.subirVideoCalled, isTrue);
    expect(
      fakeVM.archivoSubido!.path.contains("video_recortado_output"),
      isTrue,
    );
    expect(fakeVM.agregarVideoCalled, isTrue);
    expect(fakeVM.urlAgregada, "http://firebase.url/video.mp4");
  });
}
