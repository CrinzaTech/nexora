# Flutter – Paro Backend Integration (Retrofit + Dio)

This guide covers wiring the Flutter app to the Paro backend using the `retrofit` + `dio` packages.

---

## 1. Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.7.0
  retrofit: ^4.4.1
  firebase_auth: ^5.3.1
  json_annotation: ^4.9.0

dev_dependencies:
  retrofit_generator: ^8.2.1
  build_runner: ^2.4.13
  json_serializable: ^6.8.0
```

Run:

```bash
flutter pub get
```

---

## 2. Models

### `lib/data/models/upload_request.dart`

```dart
import 'package:json_annotation/json_annotation.dart';

part 'upload_request.g.dart';

@JsonSerializable()
class UploadRequest {
  final String itemId;
  final String fileType;

  const UploadRequest({required this.itemId, required this.fileType});

  factory UploadRequest.fromJson(Map<String, dynamic> json) =>
      _$UploadRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UploadRequestToJson(this);
}
```

### `lib/data/models/upload_response.dart`

```dart
import 'package:json_annotation/json_annotation.dart';

part 'upload_response.g.dart';

@JsonSerializable()
class UploadResponse {
  final String uploadUrl;
  final String fileUrl;

  const UploadResponse({required this.uploadUrl, required this.fileUrl});

  factory UploadResponse.fromJson(Map<String, dynamic> json) =>
      _$UploadResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UploadResponseToJson(this);
}
```

Generate the JSON boilerplate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 3. Retrofit API Client

### `lib/data/remote/paro_api.dart`

```dart
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../models/upload_request.dart';
import '../models/upload_response.dart';

part 'paro_api.g.dart';

@RestApi()
abstract class ParoApi {
  factory ParoApi(Dio dio, {String baseUrl}) = _ParoApi;

  @POST('/generate-upload-url')
  Future<UploadResponse> generateUploadUrl(
    @Body() UploadRequest body,
  );
}
```

---

## 4. Firebase Auth Interceptor

This interceptor automatically fetches the current user's Firebase ID token and injects it as a Bearer token on every request.

### `lib/data/remote/auth_interceptor.dart`

```dart
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // forceRefresh: false – uses cached token unless it's about to expire
      final token = await user.getIdToken();
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
```

---

## 5. Dio + API Client Setup

### `lib/data/remote/api_client.dart`

```dart
import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import 'paro_api.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _baseUrl = 'https://your-backend-url.com'; // or http://10.0.2.2:3000 for Android emulator

  late final ParoApi paroApi = ParoApi(
    Dio(BaseOptions(baseUrl: _baseUrl))
      ..interceptors.addAll([
        AuthInterceptor(),
        LogInterceptor(responseBody: true), // remove in production
      ]),
  );
}
```

> **Local dev note:**
> - Android emulator → `http://10.0.2.2:3000`
> - iOS simulator → `http://localhost:3000`
> - Physical device → your machine's LAN IP, e.g. `http://192.168.x.x:3000`

---

## 6. Upload Flow

The full upload is two steps:
1. Ask the backend for a pre-signed PUT URL.
2. PUT the file bytes directly to S3 using that URL (no auth header needed here — S3 uses the signature embedded in the URL).

### `lib/data/remote/upload_service.dart`

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/upload_request.dart';
import 'api_client.dart';

class UploadService {
  final _api = ApiClient.instance.paroApi;
  final _dio = Dio(); // plain Dio — no auth interceptor for S3

  /// Returns the permanent [fileUrl] after a successful upload.
  Future<String> uploadWardrobeImage({
    required String itemId,
    required File imageFile,
  }) async {
    // 1. Get pre-signed URL from backend
    final response = await _api.generateUploadUrl(
      UploadRequest(itemId: itemId, fileType: 'image/jpeg'),
    );

    // 2. PUT the file directly to S3
    final bytes = await imageFile.readAsBytes();

    await _dio.put(
      response.uploadUrl,
      data: Stream.fromIterable(bytes.map((b) => [b])),
      options: Options(
        headers: {
          'Content-Type': 'image/jpeg',
          'Content-Length': bytes.length,
        },
        // Disable Dio's default JSON content-type override
        contentType: 'image/jpeg',
      ),
    );

    return response.fileUrl;
  }
}
```

---

## 7. Usage Example

```dart
Future<void> onImagePicked(File image) async {
  try {
    final service = UploadService();
    final permanentUrl = await service.uploadWardrobeImage(
      itemId: 'item_abc123',
      imageFile: image,
    );

    // Store permanentUrl in Firestore or local state
    print('Uploaded: $permanentUrl');
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      // Token expired – Firebase Auth should auto-refresh on next call
    } else if (statusCode == 429) {
      // Rate limited
    } else {
      rethrow;
    }
  }
}
```

---

## 8. Error Handling Reference

| HTTP Status | Meaning | Flutter Action |
|---|---|---|
| `400` | Bad `itemId` or `fileType` | Show validation error |
| `401` | Firebase token invalid/expired | Re-authenticate or retry |
| `429` | 20 req/min limit hit | Show cooldown message |
| `500` | Backend/S3 error | Show generic retry prompt |

---

## 9. File Picker Integration (optional)

```yaml
# pubspec.yaml
dependencies:
  image_picker: ^1.1.2
```

```dart
import 'package:image_picker/image_picker.dart';

Future<void> pickAndUpload() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,   // compress before upload
    maxWidth: 1920,
  );

  if (picked != null) {
    await onImagePicked(File(picked.path));
  }
}
```

---

## Summary

```
Flutter
  └── ImagePicker → File
        └── UploadService.uploadWardrobeImage()
              ├── ParoApi.generateUploadUrl()   →  POST /generate-upload-url  (Firebase token)
              │                                 ←  { uploadUrl, fileUrl }
              └── Dio.put(uploadUrl, bytes)     →  PUT directly to S3
                                                ←  HTTP 200 (empty body)
                  fileUrl saved to Firestore
```
