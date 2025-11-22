import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sos_mascotas/vista/reportes/pantalla_mapa_osm.dart';
import 'package:sos_mascotas/vistamodelo/reportes/avistamiento_vm.dart';

class PantallaAvistamiento extends StatelessWidget {
  final AvistamientoVM? viewModelTest;
  final ImagePicker? pickerTest;
  final Widget? mapaTest;
  final Future<DateTime?> Function(BuildContext, DateTime)? datePickerTest;

  const PantallaAvistamiento({
    super.key,
    this.viewModelTest,
    this.pickerTest,
    this.mapaTest,
    this.datePickerTest,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => viewModelTest ?? AvistamientoVM(),
      child: _FormularioAvistamiento(
        pickerTest: pickerTest, // 👈 PASAMOS EL PICKER INYECTADO
        mapaTest: mapaTest,
        datePickerTest: datePickerTest,
      ),
    );
  }
}

class _FormularioAvistamiento extends StatefulWidget {
  final ImagePicker? pickerTest; // 👈 ACEPTAMOS EL PICKER
  final Widget? mapaTest;
  final Future<DateTime?> Function(BuildContext, DateTime)? datePickerTest;

  const _FormularioAvistamiento({
    this.pickerTest,
    this.mapaTest,
    this.datePickerTest,
  });

  @override
  State<_FormularioAvistamiento> createState() =>
      _FormularioAvistamientoState();
}

class _FormularioAvistamientoState extends State<_FormularioAvistamiento> {
  final formKey = GlobalKey<FormState>();

  late ImagePicker picker;

  late TextEditingController direccionCtrl;
  late TextEditingController fechaCtrl;
  late TextEditingController horaCtrl;
  late TextEditingController descripcionCtrl;

  List<File> imagenesSeleccionadas = [];

  @override
  void initState() {
    super.initState();
    picker = widget.pickerTest ?? ImagePicker();
    direccionCtrl = TextEditingController();
    fechaCtrl = TextEditingController();
    horaCtrl = TextEditingController();
    descripcionCtrl = TextEditingController();

    // Escuchamos cambios en el VM para mostrar errores/éxitos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<AvistamientoVM>();
      vm.addListener(() {
        if (!mounted) return;

        // Manejo de Mensajes (Error o Info)
        if (vm.mensajeUsuario != null) {
          final esError = vm.estado == EstadoCarga.error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(vm.mensajeUsuario!),
              backgroundColor: esError ? Colors.redAccent : Colors.green,
            ),
          );
          vm.limpiarMensaje();
        }

        // Manejo de Éxito al Guardar (Cerrar pantalla)
        if (vm.estado == EstadoCarga.exito) {
          Navigator.pop(context);
        }
      });
    });
  }

  @override
  void dispose() {
    direccionCtrl.dispose();
    fechaCtrl.dispose();
    horaCtrl.dispose();
    descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(ImageSource source, AvistamientoVM vm) async {
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => imagenesSeleccionadas.add(file));

    final url = await vm.subirFoto(file);
    if (url != null) {
      vm.avistamiento.foto = url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AvistamientoVM>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Text(
          "Registrar Avistamiento",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📸 FOTO(S)
              _sectionTitle("📸 Foto del avistamiento"),
              _card(
                child: Column(
                  children: [
                    if (imagenesSeleccionadas.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Wrap(
                          spacing: 8,
                          children: imagenesSeleccionadas
                              .map(
                                (f) => ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    f,
                                    height: 80,
                                    width: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          key: const Key('btnCamara'), // KEY PARA TEST
                          onPressed: () =>
                              _seleccionarImagen(ImageSource.camera, vm),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text("Cámara"),
                          style: _estiloBoton(
                            Colors.deepOrange,
                            const Color(0xFFFFF3E0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          key: const Key('btnGaleria'), // KEY PARA TEST
                          onPressed: () =>
                              _seleccionarImagen(ImageSource.gallery, vm),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: const Text("Galería"),
                          style: _estiloBoton(
                            Colors.orange.shade700,
                            const Color(0xFFFFF8E1),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 📍 DIRECCIÓN
              _sectionTitle("📍 Ubicación del avistamiento"),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: const Key('fieldDireccion'), // KEY PARA TEST
                      controller: direccionCtrl,
                      readOnly: true,
                      decoration: _inputDecoration("Seleccionar desde el mapa")
                          .copyWith(
                            suffixIcon: IconButton(
                              key: const Key('btnMapa'), // KEY PARA TEST
                              icon: const Icon(
                                Icons.map_outlined,
                                color: Colors.orange,
                              ),
                              onPressed: () async {
                                final resultado = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        widget.mapaTest ??
                                        const PantallaMapaOSM(),
                                  ),
                                );
                                if (resultado != null) {
                                  vm.actualizarUbicacion(
                                    direccion: resultado['direccion'] ?? '',
                                    distrito: resultado['distrito'] ?? '',
                                    latitud: resultado['lat'],
                                    longitud: resultado['lng'],
                                  );
                                  direccionCtrl.text =
                                      resultado['direccion'] ?? '';
                                }
                              },
                            ),
                          ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? "Seleccione una ubicación"
                          : null,
                    ),
                    if (vm.avistamiento.distrito.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Distrito: ${vm.avistamiento.distrito}",
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 📅 FECHA y HORA
              _sectionTitle("🕓 Fecha y hora del avistamiento"),
              _card(
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const Key('fieldFecha'), // KEY PARA TEST
                        controller: fechaCtrl,
                        readOnly: true,
                        decoration: _inputDecoration("Fecha").copyWith(
                          suffixIcon: const Icon(
                            Icons.calendar_today,
                            color: Colors.orange,
                          ),
                        ),
                        onTap: () async {
                          final fecha = await (widget.datePickerTest != null
                              ? widget.datePickerTest!(context, DateTime.now())
                              : showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                ));
                          if (fecha != null) {
                            final strFecha =
                                "${fecha.day}/${fecha.month}/${fecha.year}";
                            vm.avistamiento.fechaAvistamiento = strFecha;
                            fechaCtrl.text = strFecha;
                          }
                        },
                        validator: (v) => (v == null || v.isEmpty)
                            ? "Seleccione fecha"
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const Key('fieldHora'), // KEY PARA TEST
                        controller: horaCtrl,
                        readOnly: true,
                        decoration: _inputDecoration("Hora").copyWith(
                          suffixIcon: const Icon(
                            Icons.access_time,
                            color: Colors.orange,
                          ),
                        ),
                        onTap: () async {
                          final hora = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (hora != null) {
                            final strHora =
                                "${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}";
                            vm.avistamiento.horaAvistamiento = strHora;
                            horaCtrl.text = strHora;
                          }
                        },
                        validator: (v) =>
                            (v == null || v.isEmpty) ? "Seleccione hora" : null,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 📝 DESCRIPCIÓN
              _sectionTitle("📝 Descripción del avistamiento"),
              _card(
                child: TextFormField(
                  key: const Key('fieldDescripcion'), // KEY PARA TEST
                  controller: descripcionCtrl,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    "Ejemplo: perro marrón pequeño...",
                  ),
                  onChanged: (v) => vm.setDescripcion(v),
                  validator: (v) => (v == null || v.isEmpty)
                      ? "Ingrese una descripción"
                      : null,
                ),
              ),

              const SizedBox(height: 30),

              // 🔘 BOTÓN GUARDAR
              Center(
                child: GestureDetector(
                  key: const Key('btnGuardar'), // KEY PARA TEST
                  onTap: vm.cargando
                      ? null
                      : () {
                          if (!formKey.currentState!.validate()) return;
                          vm.guardarAvistamiento();
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: vm.cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Guardar Avistamiento",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🎨 Estilos y Widgets auxiliares (Refactorizados para limpieza)
ButtonStyle _estiloBoton(Color fg, Color bg) {
  return ElevatedButton.styleFrom(
    foregroundColor: fg,
    backgroundColor: bg,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  );
}

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  ),
);

Widget _card({required Widget child}) => Card(
  color: Colors.white,
  elevation: 1,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);

InputDecoration _inputDecoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: Colors.grey[100],
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: Colors.grey[300]!),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Color(0xFFFF9800), width: 2),
  ),
);
