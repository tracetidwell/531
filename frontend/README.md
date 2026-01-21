# 5/3/1 Training App - Flutter Frontend

## Setup Instructions

### Prerequisites
- Flutter SDK 3.16 or later
- Dart 3.2 or later

### Installation

1. **Install Flutter** (if not already installed):
   ```bash
   # Visit https://flutter.dev/docs/get-started/install
   # Or use a version manager like fvm
   ```

2. **Create the Flutter project**:
   ```bash
   cd /home/trace/Documents/531
   flutter create --org com.fiveThreeOne --project-name five_three_one_app frontend
   ```

3. **Navigate to the project**:
   ```bash
   cd frontend
   ```

4. **Add dependencies** to `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter

     # State Management
     flutter_riverpod: ^2.4.9
     riverpod_annotation: ^2.3.3

     # HTTP & API
     dio: ^5.4.0
     retrofit: ^4.0.3
     json_annotation: ^4.8.1

     # Local Database
     sqflite: ^2.3.0
     path: ^1.8.3

     # Secure Storage
     flutter_secure_storage: ^9.0.0

     # UI Components
     fl_chart: ^0.66.0
     intl: ^0.18.1

     # Navigation
     go_router: ^13.0.0

   dev_dependencies:
     flutter_test:
       sdk: flutter
     flutter_lints: ^3.0.1

     # Code Generation
     build_runner: ^2.4.7
     riverpod_generator: ^2.3.9
     retrofit_generator: ^8.0.6
     json_serializable: ^6.7.1
   ```

5. **Get dependencies**:
   ```bash
   flutter pub get
   ```

6. **Run the app**:
   ```bash
   # For mobile (iOS/Android)
   flutter run

   # For web
   flutter run -d chrome
   ```

## Project Structure (Recommended)

```
frontend/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── config/
│   │   ├── constants/
│   │   ├── router/
│   │   └── theme/
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── program/
│   │   ├── workout/
│   │   ├── progress/
│   │   └── settings/
│   ├── shared/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── services/
│   │   └── widgets/
│   └── utils/
├── test/
└── pubspec.yaml
```

## Configuration

### API Endpoint
Update the API base URL in `lib/core/config/api_config.dart`:
```dart
const String apiBaseUrl = 'http://localhost:8000/api/v1';
```

## Testing

```bash
# Run tests
flutter test

# Run tests with coverage
flutter test --coverage
```

## Building

```bash
# Build APK (Android)
flutter build apk --release

# Build IPA (iOS)
flutter build ios --release

# Build web
flutter build web
```
