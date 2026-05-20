import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/genogram_provider.dart';
import 'screens/main_screen.dart';
import 'constants/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const GenogramApp());
}

class GenogramApp extends StatelessWidget {
  const GenogramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GenogramProvider(),
      child: MaterialApp(
        title: 'Genogram Builder',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const MainScreen(),
      ),
    );
  }
}
