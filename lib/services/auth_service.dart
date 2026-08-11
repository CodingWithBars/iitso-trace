import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'activity_log_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final adminRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  try {
    final doc = await FirestoreService.admins.doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['role']?.toString().toLowerCase() ?? 'admin';
    } else if (user.email?.toLowerCase() == 'iitsoofficer@dorsu.bc') {
      return 'superadmin';
    }
  } catch (e) {
    // Permission denied or other error
  }
  return null;
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        final doc = await FirestoreService.admins.doc(cred.user!.uid).get();
        if (!doc.exists) {
          if (email.toLowerCase() == 'iitsoofficer@dorsu.bc') {
            // Auto-restore the master admin if it was accidentally deleted
            await FirestoreService.admins.doc(cred.user!.uid).set({
              'name': 'Master Officer',
              'email': email,
              'role': 'superadmin',
              'created_at': FieldValue.serverTimestamp(),
              'status': 'active',
            });
          } else {
            await _auth.signOut();
            return 'Access Denied: You do not have admin privileges.';
          }
        }

        // Log the login event
        String adminName = 'Admin';
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('name')) {
            adminName = data['name'];
          }
        } else if (email.toLowerCase() == 'iitsoofficer@dorsu.bc') {
          adminName = 'Master Officer';
        }

        await ActivityLogService.log(
          action: 'Login',
          message: 'Admin logged in',
          entityType: 'admin',
          entityId: cred.user!.uid,
          actorName: adminName,
        );
      }

      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
        case 'invalid-login-credentials':
        case 'wrong-password':
          return 'Invalid email or password.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Try again later.';
        default:
          return 'Login failed. Please try again.';
      }
    } catch (e) {
      return 'An unexpected error occurred: $e';
    }
  }

  Future<void> signOut() async {
    final uid = currentUser?.uid;
    if (uid != null) {
      try {
        ActivityLogService.log(
          action: 'Logout',
          message: 'Admin logged out',
          entityType: 'admin',
          entityId: uid,
          actorName: 'Admin',
        ).catchError((_) {});
      } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<String?> updateEmail(String currentPassword, String newEmail) async {
    if (currentUser == null) return 'No user signed in.';
    try {
      final cred = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: currentPassword,
      );
      await currentUser!.reauthenticateWithCredential(cred);

      await currentUser!.verifyBeforeUpdateEmail(newEmail);

      // Update email in firestore as well
      await FirestoreService.admins.doc(currentUser!.uid).update({
        'email': newEmail,
      });

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') return 'Incorrect current password.';
      if (e.code == 'invalid-email') return 'Invalid new email address.';
      if (e.code == 'email-already-in-use') return 'Email is already in use.';
      return e.message ?? 'Failed to update email.';
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentUser == null) return 'No user signed in.';
    try {
      final cred = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: currentPassword,
      );
      await currentUser!.reauthenticateWithCredential(cred);
      await currentUser!.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') return 'Incorrect current password.';
      if (e.code == 'weak-password') return 'New password is too weak.';
      return e.message ?? 'Failed to update password.';
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  Future<String?> createAdmin(
    String name,
    String email,
    String password,
  ) async {
    try {
      // Initialize a secondary Firebase app to prevent logging out the current admin
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'tempAdminCreator',
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final userCred = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCred.user != null) {
        await FirestoreService.admins.doc(userCred.user!.uid).set({
          'name': name,
          'email': email,
          'role': 'admin',
          'created_at': FieldValue.serverTimestamp(),
          'status': 'active',
        });
      }

      await tempApp.delete();
      return null; // success
    } on FirebaseAuthException catch (e) {
      try {
        await Firebase.app('tempAdminCreator').delete();
      } catch (_) {}

      switch (e.code) {
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'The password provided is too weak.';
        default:
          return e.message ?? 'Failed to create admin account.';
      }
    } catch (e) {
      try {
        await Firebase.app('tempAdminCreator').delete();
      } catch (_) {}
      return 'An unexpected error occurred.';
    }
  }
}

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    // Enable offline persistence
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  static FirebaseFirestore get db => _db;

  // Collections
  static CollectionReference get students => _db.collection('students');
  static CollectionReference get events => _db.collection('events');
  static CollectionReference get attendance => _db.collection('attendance');
  static CollectionReference get funds => _db.collection('funds');
  static CollectionReference get announcements =>
      _db.collection('announcements');
  static CollectionReference get admins => _db.collection('admins');
}
