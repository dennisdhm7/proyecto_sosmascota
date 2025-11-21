import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sos_mascotas/modelo/usuario.dart';

void main() {
  group('🧪 Tests del modelo Usuario', () {
    test("✔ fromMap convierte correctamente desde Firestore", () {
      final timestamp = Timestamp.fromDate(DateTime(2025, 1, 10));

      final map = {
        "nombre": "Juan Pérez",
        "correo": "juan@test.com",
        "telefono": "987654321",
        "dni": "12345678",
        "rol": "usuario",
        "estadoVerificado": true,
        "estadoRol": "activo",
        "fotoPerfil": "foto.jpg",
        "fechaRegistro": timestamp,
        "fcmToken": "abc123token",
      };

      final usuario = Usuario.fromMap(map, "UID123");

      expect(usuario.id, "UID123");
      expect(usuario.nombre, "Juan Pérez");
      expect(usuario.correo, "juan@test.com");
      expect(usuario.telefono, "987654321");
      expect(usuario.dni, "12345678");
      expect(usuario.rol, "usuario");
      expect(usuario.estadoVerificado, true);
      expect(usuario.estadoRol, "activo");
      expect(usuario.fotoPerfil, "foto.jpg");
      expect(usuario.fechaRegistro, timestamp.toDate());
      expect(usuario.fcmToken, "abc123token");
    });

    test("✔ fromMap asigna valores por defecto cuando faltan campos", () {
      final map = {"nombre": "Sin Campos"};

      final usuario = Usuario.fromMap(map, "X1");

      expect(usuario.id, "X1");
      expect(usuario.nombre, "Sin Campos");
      expect(usuario.correo, ""); // default
      expect(usuario.telefono, ""); // default
      expect(usuario.dni, ""); // default
      expect(usuario.rol, "usuario"); // default
      expect(usuario.estadoVerificado, false); // default
      expect(usuario.estadoRol, "activo"); // default
      expect(usuario.fotoPerfil, null);
      expect(usuario.fechaRegistro, null);
      expect(usuario.fcmToken, null);
    });

    test("✔ toMap convierte correctamente a Firestore Map", () {
      final fecha = DateTime(2025, 1, 10);

      final usuario = Usuario(
        id: "U100",
        nombre: "María López",
        correo: "maria@test.com",
        telefono: "987111222",
        dni: "87654321",
        rol: "usuario",
        estadoVerificado: false,
        estadoRol: "activo",
        fotoPerfil: null,
        fechaRegistro: fecha,
        fcmToken: "fcm-token-xyz",
      );

      final map = usuario.toMap();

      expect(map["nombre"], "María López");
      expect(map["correo"], "maria@test.com");
      expect(map["telefono"], "987111222");
      expect(map["dni"], "87654321");
      expect(map["rol"], "usuario");
      expect(map["estadoVerificado"], false);
      expect(map["estadoRol"], "activo");
      expect(map["fotoPerfil"], null);
      expect(map["fcmToken"], "fcm-token-xyz");
      expect(map["fechaRegistro"], Timestamp.fromDate(fecha));
    });

    test("✔ toMap usa serverTimestamp() cuando fechaRegistro es null", () {
      final usuario = Usuario(
        id: "U200",
        nombre: "Test",
        correo: "test@test.com",
        telefono: "111111111",
        dni: "12312312",
        rol: "usuario",
        estadoVerificado: false,
        estadoRol: "activo",
        fotoPerfil: null,
        fechaRegistro: null,
        fcmToken: null,
      );

      final map = usuario.toMap();

      // No podemos comparar exactamente FieldValue.serverTimestamp(),
      // pero sí verificamos que el campo existe y es FieldValue.
      expect(map["fechaRegistro"], isA<FieldValue>());
    });
  });
}
