import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class PantallaMapaOSM extends StatefulWidget {
  final LatLng? ubicacionInicial;
  final bool esAvistamiento;

  // 💉 Inyección del cliente HTTP para tests
  final http.Client? httpClient;

  const PantallaMapaOSM({
    super.key,
    this.ubicacionInicial,
    this.esAvistamiento = false,
    this.httpClient,
  });

  @override
  State<PantallaMapaOSM> createState() => _PantallaMapaOSMState();
}

class _PantallaMapaOSMState extends State<PantallaMapaOSM> {
  LatLng? _puntoSeleccionado;
  String? _direccion;
  String? _distrito;
  bool _cargando = false;
  final MapController _mapController = MapController();

  final List<String> _distritosTacna = const [
    "Alto de la Alianza",
    "Calana",
    "Ciudad Nueva",
    "Coronel Gregorio Albarracín Lanchipa",
    "Inclán",
    "La Yarada-Los Palos",
    "Pachía",
    "Palca",
    "Pocollay",
    "Sama",
  ];

  @override
  void initState() {
    super.initState();
    _puntoSeleccionado = widget.ubicacionInicial ?? LatLng(-18.0066, -70.2463);
  }

  Future<void> _buscarDireccion(LatLng punto) async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _direccion = "Obteniendo dirección...";
      _distrito = null;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${punto.latitude}&lon=${punto.longitude}',
      );

      // 💉 Usamos el cliente inyectado o creamos uno nuevo
      final client = widget.httpClient ?? http.Client();

      final res = await client.get(
        url,
        headers: {'User-Agent': 'sos_mascota_app/1.0 (https://sosmascota.org)'},
      );

      // Si creamos un cliente nuevo localmente (no inyectado), lo ideal sería cerrarlo,
      // pero http.get estático lo maneja globalmente.
      // Al usar client de instancia, Flutter recomienda cerrarlo si somos dueños,
      // pero para este caso simple basta con usarlo.

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        String direccionCompleta = (data['display_name'] ?? '').toString();
        String distritoDetectado = "Tacna";

        for (final d in _distritosTacna) {
          if (direccionCompleta.toLowerCase().contains(d.toLowerCase())) {
            distritoDetectado = d;
            break;
          }
        }

        if (mounted) {
          setState(() {
            _direccion = direccionCompleta;
            _distrito = distritoDetectado;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _direccion = "No se pudo obtener la dirección";
            _distrito = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _direccion = "Error de conexión";
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorPrincipal = widget.esAvistamiento
        ? const Color(0xFFF59E0B)
        : const Color(0xFF4D9EF6);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: colorPrincipal,
        title: Text(
          widget.esAvistamiento
              ? "Seleccionar ubicación del avistamiento"
              : "Seleccionar lugar de pérdida",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // ✅ Nuevos nombres de parámetros (flutter_map >= 6)
              initialCenter: _puntoSeleccionado ?? LatLng(-18.0066, -70.2463),
              initialZoom: 15,
              onTap: (tapPosition, point) async {
                setState(() {
                  _puntoSeleccionado = point;
                });
                await _buscarDireccion(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sosmascota.app',
              ),
              if (_puntoSeleccionado != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _puntoSeleccionado!,
                      width: 45,
                      height: 45,
                      // ✅ Nuevo parámetro 'child:' reemplaza 'builder:'
                      child: Icon(
                        Icons.location_on,
                        size: 45,
                        color: colorPrincipal,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 📋 Panel con dirección detectada
          if (_direccion != null)
            Positioned(
              bottom: 110,
              left: 16,
              right: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place, color: colorPrincipal),
                        const SizedBox(width: 6),
                        const Text(
                          "Dirección seleccionada",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _direccion ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_distrito != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            size: 18,
                            color: colorPrincipal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Distrito: $_distrito",
                            style: TextStyle(
                              fontSize: 13,
                              color: colorPrincipal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ✅ Botón confirmar ubicación
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                _cargando
                    ? "Buscando ubicación..."
                    : "Confirmar ubicación seleccionada",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorPrincipal,
                foregroundColor: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onPressed: _cargando || _puntoSeleccionado == null
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'direccion': _direccion ?? '',
                        'distrito': _distrito ?? '',
                        'lat': _puntoSeleccionado!.latitude,
                        'lng': _puntoSeleccionado!.longitude,
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }
}
