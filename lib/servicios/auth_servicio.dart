import 'package:firebase_auth/firebase_auth.dart';

/// Servicio encargado de gestionar la autenticación de usuarios mediante Firebase Auth.
///
/// Provee métodos para el registro, inicio de sesión, y verificación de correo electrónico.
class AuthServicio {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Registra un nuevo usuario en Firebase con [correo] y [clave].
  ///
  /// Retorna el `uid` (identificador único) del usuario recién creado.
  /// Puede lanzar una [FirebaseAuthException] si el correo ya existe o la clave es débil.
  Future<String> registrar(String correo, String clave) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: correo,
      password: clave,
    );
    return cred.user!.uid;
  }

  /// Envía un correo de verificación al usuario actualmente autenticado.
  ///
  /// Solo envía el correo si hay un usuario logueado y su email aún no ha sido verificado.
  Future<void> enviarVerificacionCorreo() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Recarga los metadatos del usuario actual desde el servidor de Firebase.
  ///
  /// Es **fundamental** llamar a este método para actualizar el estado [emailVerified]
  /// después de que el usuario haya hecho clic en el enlace de su correo.
  Future<void> recargarUsuario() async {
    final user = _auth.currentUser;
    if (user != null) await user.reload();
  }

  /// Indica si el correo electrónico del usuario actual ha sido verificado.
  ///
  /// Retorna `true` si el usuario existe y [emailVerified] es verdadero.
  bool get correoVerificado {
    final user = _auth.currentUser;
    return (user != null && user.emailVerified);
  }

  /// Reenvía el correo de verificación.
  ///
  /// Es un alias de [enviarVerificacionCorreo] para mayor claridad en la UI.
  Future<void> reenviarVerificacion() => enviarVerificacionCorreo();

  /// Inicia sesión con [correo] y [clave], pero impide el acceso si no está verificado.
  ///
  /// 1. Realiza el login.
  /// 2. Recarga los datos del usuario.
  /// 3. Si el correo no está verificado, lanza una [FirebaseAuthException] con el código `email-not-verified`.
  ///
  /// Retorna el objeto [User] si el acceso es exitoso.
  Future<User?> loginBloqueandoSiNoVerificado(
    String correo,
    String clave,
  ) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: correo,
      password: clave,
    );
    await cred.user?.reload();
    if (cred.user != null && !cred.user!.emailVerified) {
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Debe verificar su correo antes de continuar.',
      );
    }

    return cred.user;
  }
}
