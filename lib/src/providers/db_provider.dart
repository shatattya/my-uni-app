import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/app_database.dart';

/// A global provider that holds the single instance of our local database
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();

  // Ensure the database connection is closed when the provider is destroyed
  ref.onDispose(() => db.close());

  return db;
});