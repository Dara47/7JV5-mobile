import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'models/models.dart';
import 'services/firestore_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const JV5App());
}

class JV5App extends StatelessWidget {
  const JV5App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7J English',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEA580C)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasData) {
            return FutureBuilder<AppUser>(
              future: FirestoreService.getAppUser(snap.data!.uid),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return HomeScreen(appUser: userSnap.data!);
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
