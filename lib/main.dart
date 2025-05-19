import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart'; // Keep this import
import 'gif_list_screen.dart';
import 'gif_box.dart';
import 'models/gif_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get the application support directory instead of documents directory
  final appSupportDir = await getApplicationSupportDirectory();
  // Initialize Hive with the application support directory path
  Hive.init(appSupportDir.path);

  // Register the adapter for the GifEntry object
  Hive.registerAdapter(GifEntryAdapter());

  // Open the box for storing GifEntry objects
  await Hive.openBox<GifEntry>(gifBoxName);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Favorite GIFs',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GifListScreen(),
    );
  }
}
