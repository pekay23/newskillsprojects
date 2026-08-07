import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class ApiClient {
  // Use 10.0.2.2 for Android Emulator connecting to host localhost
  // Use localhost for iOS simulator
  final String baseUrl = "http://10.0.2.2:8080/api/v1";

  Future<void> syncLocalChanges() async {
    final queue = await DatabaseHelper.instance.getUnsyncedQueue();
    if (queue.isEmpty) return;

    for (var item in queue) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/sync/push'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "operation": item['operation'],
            "table": item['table_name'],
            "data": item['payload'], 
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 202) {
          // Sync successful, remove from local queue
          final db = await DatabaseHelper.instance.database;
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
        }
      } catch (e) {
        print("Failed to sync item ${item['id']}: $e");
        // Connection failed; keep in queue for next time
      }
    }
  }
}
