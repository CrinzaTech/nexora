# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application named **Crinza App**. The project uses Dart SDK ^3.9.2 and follows standard Flutter project conventions.

## Development Commands

### Running the App
```bash
# Run on connected device/emulator
fvm flutter run

# Run on specific device
fvm flutter run -d <device_id>

# Run in release mode
fvm flutter run --release
```

### Building
```bash
# Build Android APK
fvm flutter build apk

# Build Android app bundle
fvm flutter build appbundle

# Build iOS (requires macOS and Xcode)
fvm flutter build ios
```

### Testing & Quality
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Analyze code for issues
flutter analyze

# Format code
dart format .
```

### Dependencies
```bash
# Install dependencies
fvm flutter pub get

# Upgrade dependencies
fvm flutter pub upgrade

# Check for outdated packages
fvm flutter pub outdated
```

### Common Dependencies

This project typically uses:
- **flutter_bloc**: State management (Cubit)
- **freezed**: Immutable code generation
- **freezed_annotation**: Freezed annotations
- **dartz**: Functional programming (Either<Failure, Success>)
- **get_it**: Dependency injection / service locator
- **build_runner**: Code generation (dev dependency)
- **google_sign_in**: Google OAuth
- **flutter_dotenv**: Environment variables
- **go_router**: Declarative routing and navigation
- **flutter_launcher_icons**: App icon generation (dev dependency)
- **flutter_native_splash**: Splash screen generation (dev dependency)

## Project Structure

This project follows **feature-based folder structure** with Clean Architecture layers:

```
lib/
  main.dart                    # App entry point
  features/                    # Feature modules (Clean Architecture)
    └── your_feature/
        ├── data/              # DATA LAYER
        │   ├── models/        # DTOs, API request/response models
        │   │   └── your_model.dart
        │   └── repositories/  # Repository implementations
        │       └── your_repository_impl.dart
        ├── domain/            # DOMAIN LAYER
        │   ├── usecases/      # Business logic use cases
        │   │   └── your_usecase.dart
        │   └── repositories/  # Repository interfaces (contracts)
        │       └── your_repository.dart
        └── presentation/      # PRESENTATION LAYER
            ├── bloc/          # State management (Cubit + Freezed)
            │   ├── your_feature_cubit.dart
            │   ├── your_feature_state.dart
            │   └── your_feature_cubit.freezed.dart  # Generated
            └── pages/         # UI screens/widgets
                └── your_page.dart
  core/                        # Cross-cutting concerns
    ├── global_store/          # Global app state (auth, user data)
    ├── config/                # App configuration
    ├── router/                # App routing configuration (go_router)
    ├── utils/                 # Utility functions
    ├── widgets/               # Shared widgets (splash_screen, etc.)
    └── theme/                 # App theming (colors, sizes, typography)
test/
  widget_test.dart             # Widget tests
docs/                          # Feature documentation (tracked in git)
personal-notes/                # Personal API/working notes (excluded from git)
android/                       # Android-specific code and configuration
ios/                           # iOS-specific code and configuration
```

### Creating a New Feature

When adding a new feature, follow this structure:

1. **Create feature folder**: `lib/features/your_feature/`
2. **Data Layer**: Models + Repository implementation
3. **Domain Layer**: Use cases + Repository interface
4. **Presentation Layer**: Cubit + State + UI pages
5. **Run code generation**: `flutter pub run build_runner build --delete-conflicting-outputs`

## Platform Configuration

- **Android**: Package name `com.example.crinza_app`, configured in [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
- **iOS**: Bundle name `crinza_app`, display name "Crinza App", configured in [ios/Runner/Info.plist](ios/Runner/Info.plist)

## State Management

This project uses **Cubit + Freezed** for type-safe immutable state management:

- **flutter_bloc** for Cubit state management
- **freezed** for immutable state code generation
- **state.maybeWhen()** for pattern matching in UI

### Code Generation
```bash
# Generate Freezed code after state changes
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for continuous generation
flutter pub run build_runner watch --delete-conflicting-outputs
```

### State Definition Pattern
```dart
part of 'feature_cubit.dart';

@freezed
class FeatureState with _$FeatureState {
  const factory FeatureState.initial() = _Initial;
  const factory FeatureState.loading() = _Loading;
  const factory FeatureState.success(Data data) = _Success;
  const factory FeatureState.error(String message) = _Error;
}
```

### UI State Handling
```dart
// Use maybeWhen for safe state handling
state.maybeWhen(
  success: (data) => /* handle success */,
  error: (message) => /* handle error */,
  orElse: () => /* fallback */,
);
```

### Dependency Injection

The project uses **GetIt** service locator for dependency injection:

```dart
// Register in DI setup (typically core/config/di/)
sl.registerFactory(() => YourUseCase(sl()));
sl.registerFactory(() => YourFeatureCubit(sl()));

// Use in UI via BlocProvider
BlocProvider(
  create: (context) => sl<YourFeatureCubit>(),
  child: YourView(),
);
```

## Routing & Navigation

This project uses **go_router** for declarative routing and navigation:

- **go_router**: Declarative routing with deep linking support
- **AppRouter**: Centralized router configuration in `core/router/app_router.dart`

### Router Configuration

The router is configured in [lib/core/router/app_router.dart](lib/core/router/app_router.dart):

```dart
// Initialize router in MaterialApp
MaterialApp.router(
  routerConfig: AppRouter.router,
);
```

### Navigation Methods

Use the `RouterContext` extension for easy navigation:

```dart
// Navigate to route by name
context.goNamed('home');

// Push route (add to stack)
context.pushNamed('profile', pathParameters: {'id': '123'});

// Go back
context.pop();
```

### Route Definition Pattern

```dart
GoRoute(
  path: '/profile/:id',
  name: 'profile',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return ProfileScreen(userId: id);
  },
),
```

### Protected Routes

For authenticated routes, use redirects in go_router:

```dart
redirect: (context, state) {
  final isAuthenticated = sl<AuthCubit>().state.isAuthenticated;
  final isAuthRoute = state.matchedLocation.startsWith('/login');

  if (!isAuthenticated && !isAuthRoute) {
    return '/login';
  }
  return null;
},
```

## Design System

The project has a centralized design system in `lib/core/theme/`:

### Theme Files

- **app_colors.dart**: Color palette (primary, secondary, semantic colors)
- **app_sizes.dart**: Spacing, border radius, breakpoints
- **app_typography.dart**: Font families, weights, text styles
- **app_images.dart**: Image asset paths
- **screen.dart**: Responsive sizing utilities
- **app_theme.dart**: Material theme configuration

### Usage

```dart
// Colors
Container(color: AppColors.primary)

// Sizes
Padding(padding: EdgeInsets.all(AppSizes.paddingM))

// Typography
Text('Hello', style: AppTypography.h1)

// Images
Image.asset(AppImages.logo)

// Responsive sizing
Container(
  width: Screen.getHorizontalSize(100),
  height: Screen.getVerticalSize(50),
)
```

## Version Control

The project excludes typical Flutter/Dart build artifacts and IDE files from version control:

- **Flutter/Dart**: `.dart_tool/`, `.flutter-plugins-dependencies`, `.pub-cache/`, `.pub/`, `/build/`, `/coverage/`, `**/ios/Flutter/.last_build_id`
- **Android build outputs**: `/android/app/debug`, `/android/app/profile`, `/android/app/release`
- **IDE files**: `.idea/` (IntelliJ), `*.iml`, `*.ipr`, `*.iws`
- **Miscellaneous**: `.DS_Store`, `*.log`, `*.swp`, symbol files (`app.*.symbols`), obfuscation maps (`app.*.map.json`)
