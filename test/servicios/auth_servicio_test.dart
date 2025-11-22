import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

// A small testable copy of the method under test that allows injecting FirebaseAuth.
class TestableAuthServicio {
  final FirebaseAuth _auth;
  TestableAuthServicio(this._auth);

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

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockCred;
  late MockUser mockUser;
  late TestableAuthServicio servicio;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockCred = MockUserCredential();
    mockUser = MockUser();
    servicio = TestableAuthServicio(mockAuth);
  });

  test('returns the signed-in user when email is verified', () async {
    when(
      () => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => mockCred);
    when(() => mockCred.user).thenReturn(mockUser);
    when(() => mockUser.reload()).thenAnswer((_) async {});
    when(() => mockUser.emailVerified).thenReturn(true);

    final result = await servicio.loginBloqueandoSiNoVerificado(
      'a@b.com',
      'pass',
    );

    expect(result, equals(mockUser));
    verify(() => mockUser.reload()).called(1);
    verify(
      () => mockAuth.signInWithEmailAndPassword(
        email: 'a@b.com',
        password: 'pass',
      ),
    ).called(1);
  });

  test('throws FirebaseAuthException when email is not verified', () async {
    when(
      () => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => mockCred);
    when(() => mockCred.user).thenReturn(mockUser);
    when(() => mockUser.reload()).thenAnswer((_) async {});
    when(() => mockUser.emailVerified).thenReturn(false);

    await expectLater(
      servicio.loginBloqueandoSiNoVerificado('x@y.com', 'pw'),
      throwsA(
        isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'email-not-verified',
        ),
      ),
    );

    verify(() => mockUser.reload()).called(1);
    verify(
      () =>
          mockAuth.signInWithEmailAndPassword(email: 'x@y.com', password: 'pw'),
    ).called(1);
  });

  test('returns null when credential has no user', () async {
    when(
      () => mockAuth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => mockCred);
    when(() => mockCred.user).thenReturn(null);

    final result = await servicio.loginBloqueandoSiNoVerificado(
      'n@u.com',
      'nopass',
    );

    expect(result, isNull);
    verify(
      () => mockAuth.signInWithEmailAndPassword(
        email: 'n@u.com',
        password: 'nopass',
      ),
    ).called(1);
  });
}
