import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart'; // Import path_provider
import 'gif_box.dart';
import 'gif_list_screen.dart';
import 'models/gif_entry.dart';
import 'cache/my_cache_manager.dart'; // Ensure this is imported

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get the application support directory
  final appSupportDir = await getApplicationSupportDirectory();

  // Initialize Hive to store its files directly in a subdirectory within appSupportDir
  await Hive.initFlutter(
    '${appSupportDir.path}/hive_data',
  ); // Hive will create 'hive_data' itself

  // Register the adapter for GifEntry
  Hive.registerAdapter(GifEntryAdapter());

  // Open the Hive box for GifEntry
  await Hive.openBox<GifEntry>(gifBoxName);

  // Initialize your custom cache manager
  MyCacheManager();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Favorite GIF Organizer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GifListScreen(),
    );
  }
}
