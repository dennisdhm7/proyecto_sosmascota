import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/pantalla_chat.dart';
import '../reportes/pantalla_detalle_completo.dart';

class PantallaMapaInteractivo extends StatefulWidget {
  // 💉 Inyección de dependencias (Opcionales)
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const PantallaMapaInteractivo({super.key, this.firestore, this.auth});

  @override
  State<PantallaMapaInteractivo> createState() =>
      _PantallaMapaInteractivoState();
}

class _PantallaMapaInteractivoState extends State<PantallaMapaInteractivo> {
  final MapController _mapController = MapController();
  bool _cargando = true;
  List<Map<String, dynamic>> _puntos = [];
  Map<String, dynamic>? _seleccionado;
  String _tipoSeleccionado = "";

  // Variables locales para usar los servicios
  late final FirebaseFirestore _fs;
  late final FirebaseAuth _auth;

  @override
  void initState() {
    super.initState();
    // 💉 Inicialización inteligente:
    // Si el widget trae mocks, úsalos. Si no, usa los reales.
    _fs = widget.firestore ?? FirebaseFirestore.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;

    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // Si el widget ya no está montado, no hacemos nada
    if (!mounted) return;
    setState(() => _cargando = true);

    final List<Map<String, dynamic>> puntos = [];

    try {
      // Usamos _fs en lugar de la instancia estática
      final reportes = await _fs.collection("reportes_mascotas").get();
      for (var doc in reportes.docs) {
        final data = doc.data();
        if (data["latitud"] != null && data["longitud"] != null) {
          puntos.add({...data, "tipo": "reporte", "id": doc.id});
        }
      }

      final avistamientos = await _fs.collection("avistamientos").get();
      for (var doc in avistamientos.docs) {
        final data = doc.data();
        if (data["latitud"] != null && data["longitud"] != null) {
          puntos.add({...data, "tipo": "avistamiento", "id": doc.id});
        }
      }

      if (mounted) {
        setState(() {
          _puntos = puntos;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando mapa: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirChat() async {
    if (_seleccionado == null) return;
    final safeContext = context;

    final user = _auth.currentUser;
    if (user == null) return;

    final publicadorId = _seleccionado!["usuarioId"];
    final reporteId = _seleccionado!["id"]; // Ahora sí tenemos el ID asegurado

    if (publicadorId == user.uid) {
      if (!safeContext.mounted) return;
      ScaffoldMessenger.of(safeContext).showSnackBar(
        const SnackBar(content: Text("No puedes chatear contigo mismo.")),
      );
      return;
    }

    final chatExistente = await _fs
        .collection("chats")
        .where("publicadorId", isEqualTo: publicadorId)
        .where("usuarioId", isEqualTo: user.uid)
        .where("reporteId", isEqualTo: reporteId)
        .limit(1)
        .get();

    String chatId;
    if (chatExistente.docs.isNotEmpty) {
      chatId = chatExistente.docs.first.id;
    } else {
      final nuevoChat = await _fs.collection("chats").add({
        "reporteId": reporteId,
        "tipo": _tipoSeleccionado,
        "publicadorId": publicadorId,
        "usuarioId": user.uid,
        "usuarios": [publicadorId, user.uid],
        "fechaInicio": FieldValue.serverTimestamp(),
      });
      chatId = nuevoChat.id;
    }

    if (!safeContext.mounted) return;

    Navigator.push(
      safeContext,
      MaterialPageRoute(
        builder: (_) => PantallaChat(
          chatId: chatId,
          reporteId: reporteId,
          tipo: _tipoSeleccionado,
          publicadorId: publicadorId,
          usuarioId: user.uid,
          // Pasamos las instancias para mantener la inyección
          firebaseAuth: _auth,
          firebaseFirestore: _fs,
        ),
      ),
    );
  }

  void _mostrarInfo(Map<String, dynamic> punto) {
    setState(() {
      _seleccionado = punto;
      _tipoSeleccionado = punto["tipo"];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos padding seguro para el panel inferior
    final paddingInferior = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text("Mapa Interactivo"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos),
        ],
      ),
      body: SafeArea(
        top: false, // Ya tenemos AppBar
        child: Stack(
          children: [
            _cargando
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(-18.0066, -70.2463),
                      initialZoom: 13,
                      onTap: (tapPosition, point) {
                        setState(() => _seleccionado = null);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.sosmascota.app',
                      ),
                      MarkerLayer(
                        markers: _puntos.map((punto) {
                          final lat = punto["latitud"];
                          final lng = punto["longitud"];

                          // Validación extra por seguridad
                          if (lat is! num || lng is! num) {
                            return const Marker(
                              point: LatLng(0, 0),
                              child: SizedBox(),
                            );
                          }

                          final esReporte = punto["tipo"] == "reporte";
                          final color = esReporte
                              ? const Color(0xFF4D9EF6)
                              : const Color(0xFFF59E0B);

                          return Marker(
                            width: 50,
                            height: 50,
                            point: LatLng(lat.toDouble(), lng.toDouble()),
                            child: GestureDetector(
                              onTap: () => _mostrarInfo(punto),
                              child: Icon(
                                Icons.location_on,
                                color: color,
                                size: 40,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
            if (_seleccionado != null) _buildInfoCard(context, paddingInferior),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, double paddingInferior) {
    final data = _seleccionado!;
    final esReporte = _tipoSeleccionado == "reporte";
    final fotos = (data["fotos"] ?? []) as List;
    final urlFoto = esReporte
        ? (fotos.isNotEmpty ? fotos.first : null)
        : (data["foto"] ?? "");

    final nombre = esReporte
        ? (data["nombre"] ?? "Mascota sin nombre")
        : (data["direccion"] ?? "Avistamiento");
    final descripcion = esReporte
        ? (data["caracteristicas"] ?? "Sin descripción")
        : (data["descripcion"] ?? "Sin descripción");
    final direccion = data["direccion"] ?? "Zona no especificada";
    // Manejo seguro de fecha (puede venir como String o Timestamp)
    final fechaRaw = esReporte
        ? data["fechaPerdida"]
        : data["fechaAvistamiento"];
    final fecha = fechaRaw?.toString() ?? "";

    final color = esReporte ? Colors.blueAccent : Colors.orangeAccent;

    return Positioned(
      bottom: 20 + paddingInferior,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: urlFoto != null && urlFoto.toString().isNotEmpty
                      ? Image.network(
                          urlFoto,
                          width: 75,
                          height: 75,
                          fit: BoxFit.cover,
                          // Manejador de error de imagen
                          errorBuilder: (ctx, obj, trace) => Container(
                            width: 75,
                            height: 75,
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          ),
                        )
                      : Container(
                          width: 75,
                          height: 75,
                          color: Colors.grey.shade200,
                          child: Icon(
                            esReporte ? Icons.pets : Icons.visibility,
                            size: 40,
                            color: color,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.grey.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        direccion,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: color, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            fecha,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(thickness: 1),
            Text(
              esReporte
                  ? "Tipo: ${data["tipo"] ?? "-"}  •  Raza: ${data["raza"] ?? "-"}"
                  : "Avistamiento registrado",
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.teal.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              descripcion,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.info_outline),
                  label: const Text("Ver detalle"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.teal.shade700,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaDetalleCompleto(
                          data: data,
                          tipo: _tipoSeleccionado,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text("Contactar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _abrirChat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
