import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:sos_mascotas/vista/auth/pantalla_registro.dart';
import 'package:sos_mascotas/vistamodelo/auth/registro_vm.dart';

@GenerateMocks([RegistroVM])
import 'pantalla_registro_test.mocks.dart';

void main() {
  late MockRegistroVM mockVM;

  setUp(() {
    mockVM = MockRegistroVM();
  });

  Future<void> cargarPantalla(WidgetTester tester) async {
    // 1. Pantalla grande para evitar overflow
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        // 2. Texto pequeño
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1200, 2400),
            textScaler: TextScaler.linear(0.5),
          ),
          child: ChangeNotifierProvider<RegistroVM>.value(
            value: mockVM,
            child: const PantallaRegistro(),
          ),
        ),
      ),
    );
  }

  testWidgets('🟢 Debe mostrar todos los campos de registro', (
    WidgetTester tester,
  ) async {
    when(mockVM.dniCtrl).thenReturn(TextEditingController());
    when(mockVM.nombreCtrl).thenReturn(TextEditingController());
    when(mockVM.correoCtrl).thenReturn(TextEditingController());
    when(mockVM.claveCtrl).thenReturn(TextEditingController());
    when(mockVM.telefonoCtrl).thenReturn(TextEditingController());
    when(mockVM.formKey).thenReturn(GlobalKey<FormState>());
    when(mockVM.cargando).thenReturn(false);
    when(mockVM.buscandoDni).thenReturn(false);
    when(mockVM.error).thenReturn(null);

    await cargarPantalla(tester);
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.byType(TextFormField), findsAtLeastNWidgets(1));
    expect(find.text('Registrarse'), findsOneWidget);
  });

  testWidgets('🔵 Debe buscar DNI y llenar nombre (Simulado)', (
    WidgetTester tester,
  ) async {
    final dniCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();

    when(mockVM.dniCtrl).thenReturn(dniCtrl);
    when(mockVM.nombreCtrl).thenReturn(nombreCtrl);
    when(mockVM.correoCtrl).thenReturn(TextEditingController());
    when(mockVM.claveCtrl).thenReturn(TextEditingController());
    when(mockVM.telefonoCtrl).thenReturn(TextEditingController());
    when(mockVM.formKey).thenReturn(GlobalKey<FormState>());
    when(mockVM.cargando).thenReturn(false);
    when(mockVM.buscandoDni).thenReturn(false);
    when(mockVM.error).thenReturn(null);

    when(mockVM.buscarYAutocompletarNombre()).thenAnswer((_) async {
      nombreCtrl.text = "Juan Perez";
      return true;
    });

    await cargarPantalla(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'DNI'),
      '12345678',
    );

    final btnBuscar = find.text('Buscar');
    await tester.tap(btnBuscar);
    await tester.pump();

    verify(mockVM.buscarYAutocompletarNombre()).called(1);
    expect(nombreCtrl.text, "Juan Perez");
  });

  testWidgets('🔴 Debe mostrar validaciones requeridas', (
    WidgetTester tester,
  ) async {
    // Creamos una Key real para controlarla
    final formKey = GlobalKey<FormState>();

    when(mockVM.dniCtrl).thenReturn(TextEditingController());
    when(mockVM.nombreCtrl).thenReturn(TextEditingController());
    when(mockVM.correoCtrl).thenReturn(TextEditingController());
    when(mockVM.claveCtrl).thenReturn(TextEditingController());
    when(mockVM.telefonoCtrl).thenReturn(TextEditingController());

    // Asignamos la key real al mock
    when(mockVM.formKey).thenReturn(formKey);

    when(mockVM.cargando).thenReturn(false);
    when(mockVM.buscandoDni).thenReturn(false);
    when(mockVM.error).thenReturn(null);

    // ✅ CORRECCIÓN MAESTRA:
    // Cuando el botón llame a registrarUsuario, forzamos la validación manualmente
    // porque el Mock no tiene lógica interna.
    when(mockVM.registrarUsuario()).thenAnswer((_) async {
      formKey.currentState?.validate(); // Esto pinta los errores rojos en la UI
      return false;
    });

    await cargarPantalla(tester);
    await tester.pumpAndSettle();

    final btnRegistrar = find.text('Registrarse');

    await tester.ensureVisible(btnRegistrar);
    await tester.pumpAndSettle();

    // Pulsar botón
    await tester.tap(btnRegistrar);
    await tester.pumpAndSettle(); // Esperar repintado

    // Verificar que aparecieron los textos de error
    expect(find.text('Ingrese DNI'), findsOneWidget);
    expect(find.text('Nombre requerido'), findsOneWidget);
  });
}
