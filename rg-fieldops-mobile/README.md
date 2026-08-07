# Raymond Gray Field Ops Mobile App

This directory contains the scaffolding for the Flutter mobile application, designed for field technicians. It focuses on offline-first capabilities.

### Key Features Implemented:
1. **Local SQLite Database (`sqflite`)**: Stores work orders locally on the device (`lib/services/database_helper.dart`).
2. **Sync Queue**: Any mutations (INSERT, UPDATE) are appended to a local sync queue table.
3. **Background Sync (`api_client.dart`)**: Pushes pending queued items to the main API Gateway when the user initiates a sync (or automatically via background jobs in a full implementation).

### Setup Instructions
To compile and run this app, you need the [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.

```bash
flutter pub get
flutter run
```
