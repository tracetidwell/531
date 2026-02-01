# Frontend Testing Guide

## Overview

This document describes the testing setup for the 5/3/1 Flutter app.

## Test Structure

```
test/
├── models/                    # Model serialization tests
│   ├── auth_models_test.dart
│   ├── workout_models_test.dart
│   ├── rep_max_models_test.dart
│   └── program_models_test.dart
├── providers/                 # State management tests
│   └── (future: provider tests with mocking)
└── widget_test.dart          # Widget tests
```

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/models/auth_models_test.dart

# Run tests matching pattern
flutter test --name "AuthResponse"

# Run with verbose output
flutter test --reporter expanded
```

## Test Dependencies

- `flutter_test` - Flutter's built-in test framework
- `mockito` - Mocking library for Dart
- `build_runner` - Code generation for mockito

## Writing Tests

### Model Tests

Model tests verify JSON serialization/deserialization:

```dart
test('Model.fromJson parses correctly', () {
  final json = {'field': 'value'};
  final model = Model.fromJson(json);
  expect(model.field, equals('value'));
});
```

### Provider Tests

Provider tests verify state management logic:

```dart
test('Provider updates state correctly', () async {
  final container = ProviderContainer();
  final notifier = container.read(myProvider.notifier);

  await notifier.someAction();

  expect(container.read(myProvider).someValue, equals(expected));
});
```

## Coverage

Generate coverage report:

```bash
flutter test --coverage
# Coverage report in coverage/lcov.info
```

View HTML report (requires lcov):

```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```
