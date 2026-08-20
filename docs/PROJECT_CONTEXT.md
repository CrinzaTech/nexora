# Crinza LMS — Project Context

> Architectural reference for AI assistants and engineers onboarding to the Crinza Flutter client. Focus is on **system design decisions, contracts, and trade-offs**, not UI scaffolding.

---

## 1. Project Overview

**Crinza** is a mobile Learning Management System (LMS) delivered as a Flutter application targeting Android and iOS. The product surfaces paid online courses (video, PDF, image, ZIP, and assignment-based nodes) sold via Razorpay, with a live community chat layer on top of SignalR.

### Primary users
- **Learners (B2C)** — buy individual courses or tiered plans, consume curriculum nodes, submit graded assignments, and interact with cohort chat groups.
- **Authenticated users only** — OTP-based login (phone or email via the v2 endpoint pair). There is no anonymous browse mode; every API call sits behind a bearer token issued at `verify-otp-v2`.
- **Paid learners** — get gated access to chat groups, downloadable assets, and the assignment grading pipeline. The boundary is enforced server-side; the client mirrors the `isPaid` / `coursePurchasedId` signals coming back in dashboard / course payloads.

The backend is an ASP.NET Core service exposing REST endpoints under `/api/v1/...` plus a SignalR hub for chat. The client never talks to Razorpay or third-party services directly except for the Razorpay checkout sheet — order creation, signature verification, and chat-token minting all round-trip through our backend.

---

## 2. Core Tech Stack

### Runtime
- **Dart SDK**: `^3.9.2` (FVM-pinned; commands prefixed with `fvm flutter`)
- **Flutter**: stable channel, compatible with Dart 3.9
- **Platforms**: Android (Kotlin host activity) + iOS (Swift `AppDelegate`)

### State, DI, routing
- `flutter_bloc` ^8.1.6 — **Cubit only**, never raw `Bloc` (no event sourcing in this codebase)
- `freezed` ^2.5.2 + `freezed_annotation` — sealed state unions; UI always pattern-matches via `state.maybeWhen(...)` (this is a hard convention — see `MEMORY.md`)
- `dartz` ^0.10.1 — `Either<Failure, Success>` is the universal repository return type
- `get_it` ^7.6.4 — service locator (`sl<T>()`), wired in `core/config/di/dependency_injection.dart`
- `go_router` ^14.6.2 — single `AppRouter.router` instance, declarative; all gated routes pass `coursePurchasedId` as a query param

### Networking
- `dio` ^5.0.0 — singleton, configured in `core/network/dio_client.dart` (15 s connect/send, 30 s receive)
- `retrofit` ^4.0.0 — `ApiClient` (`@RestApi`) defines the entire surface. **`api_client.g.dart` is hand-maintained** — `retrofit_generator` is excluded due to SDK incompatibility. New endpoints must be added to both files.
- `http` ^1.6.0 — used only by SignalR's transport layer
- `signalr_netcore` ^1.4.4 — chat hub client (ReceiveMessage / MessageDeleted / typing events; invokes SendMessage / JoinGroup / LeaveGroup)

### Firebase
- `firebase_core` ^4.6.0, `firebase_messaging` ^16.0.4, `firebase_crashlytics` ^5.0.4
- FCM token sync is fire-and-forget at cold start via `ProfileCubit.syncFcmToken`
- Background handler registered **before** any other FCM call (required contract)
- Crashlytics gated on `!kDebugMode`; both `FlutterError.onError` and `PlatformDispatcher.instance.onError` redirect to `recordError(fatal: true)`

### Auth & session
- `flutter_secure_storage` ^9.2.2 — token at rest in Android Keystore / iOS Keychain
- `SessionService` is the only abstraction that touches secure storage; everything else reads via DI

### Payments
- `razorpay_flutter` ^1.3.6 — checkout sheet only; server mints orders and verifies signatures

### Notifications
- `flutter_local_notifications` ^17.2.3 — iOS remote push is **gated on a paid Apple Developer account**; until that lands, every alert (including foreground FCM bridges) goes through the local plugin
- `timezone` ^0.9.4 — scheduled notifications

### Media & files
- `video_player` ^2.10.1 + `chewie` ^1.13.0 — network HLS/MP4 playback
- `syncfusion_flutter_pdfviewer` ^33.1.47 — PDF rendering with custom backdrop theming
- `file_picker` ^8.1.4 — assignment submissions (PDFs / images)
- `image_picker` ^1.1.2 — profile photo
- `cached_network_image` ^3.4.1 — image cache
- `path_provider` ^2.1.5

### Security
- `flutter_jailbreak_detection` ^1.10.0 — iOS jailbreak probe (Android root signal is reported for telemetry only; not authoritative due to OEM false positives)

### UI / utilities
- `flutter_dotenv` ^5.1.0 — `.env` shipped as asset; `BASE_URL` is required (asserted on Dio bootstrap)
- `go_router`, `google_fonts`, `intl`, `shimmer`, `auto_size_text`, `awesome_snackbar_content`, `pinput`, `readmore`, `flutter_markdown`, `argon_buttons_flutter_fix`, `flutter_spinkit`, `flutter_native_splash`, `package_info_plus`, `url_launcher`

### Codegen / tooling
- `build_runner` ^2.4.13, `freezed` ^2.5.2, `json_serializable` ^6.8.0
- `flutter_launcher_icons` ^0.14.1 — driven by `BrandingConfig` (multi-brand support: `crinesta` red-eye logo on current build)
- `flutter_native_splash` ^2.4.7

---

## 3. Architectural Pattern

### Feature-first + Clean Architecture (3 layers)

```
lib/
  main.dart                # Bootstrap + zone-guarded init pipeline
  features/<feature>/
    data/
      models/              # JSON parsing — tolerant of casing drift & nested {data: {...}}
      repositories/        # *RepositoryImpl — returns Either<Failure, T>
    domain/
      repositories/        # Abstract contracts
      usecases/            # One-method classes; thin pass-through to repos
    presentation/
      bloc/                # *Cubit + *State (freezed union)
      pages/               # Screens
      widgets/             # Feature-scoped widgets
  core/
    config/                # env_config, di/
    network/               # dio_client, api_client (Retrofit), api_endpoints,
                           # auth_interceptor, network_exception_mapper
    error/                 # failures.dart (freezed: network / server / unknown)
    security/              # device_security_guard, screen_capture_guard, security_wrapper
    services/              # fcm_service, local_notification_service,
                           # notification_router, content_completion_service
    session/               # session_service (secure storage façade)
    router/                # app_router.dart, app_routes.dart
    theme/                 # app_colors, app_sizes, app_typography, screen.dart,
                           # branding_config (multi-brand)
    widgets/               # Shared UI components
    utils/                 # Cross-cutting helpers
```

### Cubit + Freezed + Either — the canonical flow

Every feature follows the same shape:

1. **Repository** (`*RepositoryImpl`) wraps the Retrofit call in `try/on DioException/catch` and returns `Either<Failure, Model>`. Errors funnel through `mapDioExceptionToFailure` (see §5).
2. **Use case** is a single-method invokable class — kept even though it's a one-liner, because it makes DI graph wiring uniform and tests stay simple.
3. **Cubit** emits `loading → success | error` via a freezed union. UI **always** consumes states with `maybeWhen(...)` (sealed-class `switch` is banned — see auto-memory `feedback_state_pattern`).
4. **Page** is wrapped in a `BlocProvider(create: (_) => sl<XCubit>())`. Razorpay-style screens use `MultiBlocProvider` so callbacks run inside a State that can resolve all cubits.
5. **Global cubits** (currently only `ProfileCubit`) are registered as DI singletons and provided via `BlocProvider.value` at the app root in `main.dart`, so home / profile / edit-profile observe a single instance across navigation.

### Standard state shape

```dart
@freezed
class FeatureState with _$FeatureState {
  const factory FeatureState.initial() = _Initial;
  const factory FeatureState.loading() = _Loading;
  const factory FeatureState.success(Data data) = _Success;
  const factory FeatureState.error(String message) = _Error;
}
```

UI:
```dart
state.maybeWhen(
  success: (data) => /* render */,
  error: (message) => /* snackbar */,
  orElse: () => const ProgressIndicator(),
);
```

### Routing

`AppRouter.router` (single GoRouter) defines all routes in `core/router/app_router.dart`. Conventions:
- Gated content routes accept `coursePurchasedId` as a query param. Passing `0` (or omitting it) puts the viewer in **preview mode** — playback works but completion tracking is disabled.
- Each route's `builder` is responsible for creating any cubit the page needs, via `BlocProvider(create: (_) => sl<X>())`.
- `RouterContext` extension (`context.goNamed`, `context.pushNamed`, `context.pop`) is the standard navigation API.

### Multi-brand theming

`BrandingConfig` drives logo, app name (used in Razorpay merchant copy and OS shell), and asset paths. The current branch ships the Crinesta red-eye glyph; the same code path supports rebrand-by-config.

---

## 4. High-Complexity Features

### 4.1 Hybrid Video / Content Piracy Prevention

The piracy story is **defense-in-depth at three layers**, with the boundary deliberately drawn so that *server policy* is authoritative and the client just enforces it.

#### Layer A — Native screen-capture blocking (`crinza/screen_capture` MethodChannel)

| Platform | Mechanism |
|---|---|
| **Android** | `Window.addFlags(FLAG_SECURE)` in `MainActivity.onCreate`. The OS kernel itself blacks out screenshots and the screen-recorder / Cast pipeline. Flutter toggles via `setAllowed(bool)`. |
| **iOS** | No `FLAG_SECURE` analogue. `AppDelegate` observes `UIScreen.capturedDidChangeNotification`; when `UIScreen.main.isCaptured` is true it overlays a full-screen black `UIView` (with a label so users know it's intentional). Engaged on launch and on every status change. |

**Secure by default**: both platforms engage protection at activity / app launch — *before* Dart has booted. The only way protection is *loosened* is if the server-returned profile carries `isScreenCaptureAllowed: true`, which is reflected through `ProfileCubit` → `ScreenCaptureGuard.instance.setAllowed(true)`. On logout we re-tighten.

- Singleton (`ScreenCaptureGuard.instance`) because the platform state is global.
- `_lastApplied` mirror to short-circuit redundant calls during pull-to-refresh storms.
- Failures in the channel are **swallowed**: if the native side fails, we leave the safer (blocked) state.

#### Layer B — Device integrity gate (`crinza/device_security` MethodChannel + `flutter_jailbreak_detection`)

`DeviceSecurityGuard.probe()` returns a `DeviceSecurityVerdict { isCompromised, developerModeEnabled, jailbroken }`:

- **Android**: queries `Settings.Global.DEVELOPMENT_SETTINGS_ENABLED`. Developer mode → block. Root signals are intentionally **not authoritative** here (too many OEM ROM false positives); recorded for telemetry only.
- **iOS**: `FlutterJailbreakDetection.jailbroken` is the authoritative signal.
- **Debug / profile builds**: the audit is a no-op so we can dogfood on emulators.

`SecurityWrapper` sits **above `MaterialApp.router`** in the widget tree. It probes on first frame and re-probes on every `AppLifecycleState.resumed` (catches users who toggle developer options while backgrounded). When compromised, it swaps the entire app for a non-dismissible `_SecurityBlockScreen` wrapped in its own `MaterialApp` — no deep link or system back can navigate past it. `PopScope(canPop: false)` guards the back button.

#### Layer C — Per-content client-side protections in the viewers

- **Video** (`video_player_page.dart`): standard network playback via `video_player` + `chewie`. The page also drives the **completion contract** (see §4.1.d).
- **PDF** (`pdf_viewer_page.dart`): `SfPdfViewer.network` with custom backdrop. Completion fires at ≥75% page progress.
- Both viewers honour `coursePurchasedId == 0 || nodeId.isEmpty` as "preview mode" — no listener is attached at all, so previews don't generate completion POSTs.

#### Layer d — Session-scoped completion service (`ContentCompletionService`)

DI singleton tracking which curriculum nodes the current session has marked complete:

- Key: `"$coursePurchasedId|$jsonContentId"`.
- Two sets: `_marked` (success) and `_inFlight` (concurrent-call guard — video listeners can fire twice at the 75% boundary).
- Network failures are *not* added to `_marked` → next threshold retries.
- Cache lives for the app run; the backend is the source of truth across cold-launches.
- Viewers read `isMarked(...)` on `initState` and skip plumbing entirely when the node was already completed this session.

#### Web target

The current build is **Android + iOS only**. `BasicCaptureGuard.setAllowed` is a no-op outside those two platforms. A web target would need a separate strategy (HLS + signed cookies + DRM at the manifest level); none is currently implemented, and the screen-capture posture there would be effectively *advisory only* (the browser sandbox has no FLAG_SECURE).

---

### 4.2 Large File Upload Handling (Dio + Retrofit multipart)

Two upload surfaces exist today:

1. **Profile photo** (`PUT /api/v1/user-profile`) — small, single image.
2. **Assignment submission** (`POST /api/v1/course/assignment`) — multipart with `CourseId`, `AssignmentId`, `JsonNodeId`, `SubmissionId`, `SubmissionFile`.

Both are declared on `ApiClient` with `@Part(name: ..., File ...)` annotations. The hand-maintained `api_client.g.dart` builds a `FormData` and uses `MultipartFile.fromFile(file.path)`.

#### Submission state machine (assignment cubit)

`AssignmentCubit.submit()` runs a deliberately careful state machine because the backend treats `submissionId` as create-vs-update:

- `submissionId == 0` → backend creates a fresh row.
- non-zero → backend updates that specific row, identity-tied to the user.

The flow:

1. Cubit asserts `nodeId.isNotEmpty` at the edge (guards against malformed callers before the network).
2. Emits `submitting(current)` — UI keeps the existing assignment rendered, just disables the submit button.
3. Calls the repo. On failure: emits `error(message)` → `loaded(current)` (so the user can retry from a fully rendered page, not a blank error screen).
4. On success: **merges** echoed fields onto `current` — critically, **never invents a submission id**. If the backend's submit response doesn't echo one, the merge keeps the previous id (0 stays 0).
5. Emits `submitted(merged)` for the listener (snackbars / haptics).
6. Silently refetches the assignment so the canonical, backend-stamped `submissionId` lands *before* the user can submit again. Without this, a follow-up resubmit could land with a stale id and either create a duplicate row or update someone else's submission.

#### Real-time progress tracking — current state

**There is no `onSendProgress` callback wired today.** The Retrofit-declared endpoints don't expose Dio's progress callback, and `api_client.g.dart` does not pass one through. Submission UX is currently binary (button → spinner → done). For large file flows (course videos, large submission PDFs), the planned approach is one of:

- Drop down from Retrofit to a direct `Dio.post(..., onSendProgress: (sent, total) {...})` call inside a custom repository method, exposing `Stream<double>` from the cubit (a `progress` state factory on the freezed union).
- Or, keep Retrofit declarations but inject a `progress: StreamController<double>` through a custom `Dio` interceptor that taps `RequestOptions.onSendProgress`.

This is called out in §6 as an active bottleneck — instructors with weak uplinks can't tell whether the upload is alive.

#### Network timing for uploads

`dio_client.dart` sets `sendTimeout: 15 s`. This is too short for large multipart uploads on slow networks and is on the list to be either raised globally or overridden per-request when the progress story lands.

---

### 4.3 Razorpay Subscription / Payment Flow

The payment surface is deliberately **server-amount-authoritative (v2)** — the client never asserts the chargeable amount. The end-to-end flow:

```
User taps Buy Now
   ↓
PricingTiersCubit.load(courseId)
   ↓ (tier list returned)
   ├── empty       → snackbar "Pricing unavailable"
   ├── length == 1 → auto-flow into pricing breakdown
   └── length > 1  → ChoosePlanBottomSheet → user picks tier
   ↓
CoursePricingCubit.load(courseId, priceId)
   ↓
EnrollmentBottomSheet (shows breakdown — tax, internet charges, platform fee, coupon)
   ↓
PaymentCubit.createOrder(courseId, priceId)        ← POST /api/v1/payments/create-order-v2
   ↓
state == orderReady(CreateOrderResponse)
   ├── isCourseFree == true → skip Razorpay, treat as enrolled (100%-off coupon case)
   └── else → _openRazorpay(order) with prefill from ProfileCubit
                ↓
       Razorpay native sheet
                ↓
       on EVENT_PAYMENT_SUCCESS → PaymentCubit.verifyPayment(orderId, paymentId, signature)
                                  ↓ POST /api/v1/payments/verify-payment
                                  ↓
                            paymentSuccess → onPurchased() callback
       on EVENT_PAYMENT_ERROR  → PaymentCubit.onPaymentFailed(msg)
```

#### Architectural decisions

- **v2 derives the amount on the server** from `(courseId, priceId)`. The client only forwards ids; the backend resolves the tier, applies tax / platform fee / coupon, and returns the Razorpay order with the final amount. This kills any "client tampered with the amount" attack class.
- **`isCourseFree` short-circuit**: when a 100%-off coupon brings the total to zero, the backend enrols the user as part of order creation and returns `isCourseFree: true`. The client must not call `Razorpay.open` in that case — it would crash the sheet with a zero-amount order.
- **Razorpay SDK lifecycle**: `Razorpay()` is constructed in `initState` and `clear()`-ed in `dispose`. The three event handlers (`EVENT_PAYMENT_SUCCESS`, `EVENT_PAYMENT_ERROR`, `EVENT_EXTERNAL_WALLET`) all close over `context.read<PaymentCubit>()`. For this to work, **the `MultiBlocProvider` MUST live above the State** that registers the handlers — if providers were created inside `State.build()`, the callbacks would resolve them through the wrong element and throw `Could not find Provider`. This is a real foot-gun and is commented at the top of `view_demo_buy_now_row_widget.dart`.
- **Prefill** (`name`, `email`, `contact`) is read from the global `ProfileCubit` via `state.maybeWhen(loaded | updated | updating: (p) => p, orElse: () => null)`. Saves the user re-typing what they entered at signup. We only forward keys that are non-empty so we don't ship blanks into Razorpay's contact validator.
- **Latches** (`_enrolmentSheetOpen`, `_planSheetOpen`) prevent the BlocListeners from re-opening sheets on idempotent cubit emissions. After the sheet closes, the corresponding cubit is `reset()`-ed so the next tap re-fires the listener (Bloc suppresses identical states by default).
- **Signature verification** is non-optional. The client trusts only the backend's `success: true` response from `verify-payment`. The Razorpay-side success event is *not* sufficient — the signature has to round-trip and verify on the server.

#### Subscriptions

Despite the term "subscription" in product copy, the current implementation models **one-time purchases per pricing tier**, not recurring subscriptions. Razorpay Subscriptions API is not wired. "Tiered plans" are different price points for the same course (e.g. self-paced vs cohort), each a single charge.

---

## 5. API & Backend Strategy

### Transport

- All HTTP via the singleton `Dio` from `createDioClient()`.
- `baseUrl` from `.env` — asserted non-empty at bootstrap (`assert(baseUrl.isNotEmpty, ...)`).
- Default headers: `Content-Type: application/json`, `Accept: application/json`.
- Timeouts: 15 s connect, 15 s send, 30 s receive.
- `LogInterceptor` in `kDebugMode` only (full bodies + errors).

### `AuthInterceptor`

Injects the bearer token from `SessionService` on every outbound request. The token is minted at `verify-otp-v2` and stored in secure storage. The interceptor does not currently handle 401 refresh — token expiry kicks the user back to login.

### Retrofit surface (`core/network/api_client.dart`)

Single `@RestApi` abstract — covers auth (OTP v1 + v2), profile, dashboard, courses (list / detail v2 / trending / search / by-tile / by-category / continue / my-courses / rewatch / completion / reviews / pricing-v2), transactions, assignments (get + submit multipart), notifications (list + read-status), chat (groups / token-v2 / messages / delete), and payments (create-order-v2 + verify-payment).

**Chat endpoints take an explicit `@Header('Authorization')`** rather than going through `AuthInterceptor`, because they need the dedicated chat token (from `generate-token-v2`), not the main app token. The chat token is also used for the SignalR hub bearer.

`api_client.g.dart` is **hand-maintained** — `retrofit_generator` is excluded due to SDK incompatibility. New endpoints require manual edits to the generated file.

### Error handling — `Failure` sealed type

`core/error/failures.dart`:

```dart
Failure.network({required message})
Failure.server({required message, statusCode})
Failure.unknown({required message})
```

`mapDioExceptionToFailure(DioException)` is the funnel:

- `connectionTimeout` / `sendTimeout` / `receiveTimeout` → `Failure.network('Connection timed out…')`
- `connectionError` → `Failure.network('No internet connection.')`
- `badResponse` → `Failure.server(message: _extractServerMessage(response) ?? 'Server error (N)', statusCode: …)`
- `cancel` → `Failure.unknown('Request was cancelled.')`
- `badCertificate` → `Failure.network('SSL certificate error.')`
- `unknown` → `Failure.unknown(e.message ?? '...')`

#### Server message extraction — casing tolerance

The backend is **not consistent** about JSON casing:

- `Message` (PascalCase) on auth + assignment endpoints
- `message` (camelCase) on courses + payments

`_extractServerMessage` walks a list of candidate keys (`message`, `Message`, `error`, `Error`, `errorMessage`, `ErrorMessage`, `detail`, `Detail`) and returns the first non-empty string. Falls through to the caller's `"Server error (N)"` default.

This pattern repeats inside many `*.fromJson` factories — see `CreateOrderResponse.fromJson`, which accepts both flat shape and `{ "data": { ... } }` nesting, and falls back across `orderId | id`, `keyId | key`, etc.

### Repository pattern

Standard contract:

```dart
Future<Either<Failure, T>> someMethod(...) async {
  try {
    final json = await _apiClient.someEndpoint(...);
    final success = json['success'] as bool? ?? true;
    if (!success) {
      return Left(Failure.server(message: json['message']?.toString() ?? '...'));
    }
    return Right(T.fromJson(json));
  } on DioException catch (e) {
    return Left(mapDioExceptionToFailure(e));
  } catch (e) {
    return Left(Failure.unknown(message: e.toString()));
  }
}
```

The `success: bool` envelope is honoured wherever the backend ships it. Missing → assume true (some endpoints return raw payloads on 200).

### Data parsing — tolerant models

Every model's `fromJson` is written to **tolerate drift** rather than assume schema fidelity:

- Optional fields default to safe values (`'' / 0 / false`) instead of throwing.
- Both flat and `{data: {...}}`-wrapped shapes are accepted.
- Mixed casing of bool / id fields is handled (`isScreenCaptureAllowed` vs `IsScreenCaptureAllowed`).
- `num?.toInt()` casts guard against ints arriving as doubles.

This is intentional — the backend is in active flux and we'd rather degrade gracefully than crash the screen.

### Real-time (SignalR)

`signalr_chat_service.dart` connects to the ASP.NET Core hub using the chat token. Receives `ReceiveMessage`, `MessageDeleted`, typing events; invokes `SendMessage`, `JoinGroup`, `LeaveGroup`. REST endpoints (`GET /chat-group/{id}/messages`, `DELETE /chat-group/messages/{id}`) are used for history and moderation.

### Bootstrap pipeline (`main.dart`)

`runZonedGuarded` wraps everything. Inside, each init step is run through `_safeInit(name, fn)` which catches exceptions, logs them, and lets the next step proceed. Failed steps don't take down the app — the user lands on splash / login rather than an instant exit. Init order matters:

1. `dotenv.load` (`.env` as Flutter asset)
2. `Firebase.initializeApp`
3. Crashlytics callbacks (`FlutterError.onError`, `PlatformDispatcher.instance.onError`) — set after Firebase init so they have an app to record into
4. `FirebaseMessaging.onBackgroundMessage` — must come before any other FCM call
5. `SessionService.init`
6. `LocalNotificationService.init` (with `onTap` deep-link router)
7. `FcmService.init` (warm-resume + cold-start deep links)
8. `setupLocator()` (DI registrations)
9. `ProfileCubit.syncFcmToken` (fire-and-forget)
10. `SystemChrome.setPreferredOrientations([portraitUp, portraitDown])`
11. `FlutterNativeSplash.remove`
12. `runApp(CrinzaApp)` → `SecurityWrapper > MaterialApp.router`

---

## 6. Current Status & Bottlenecks

### In active development

| Area | Status | Notes |
|---|---|---|
| **OTP v2 (email + phone)** | Done | `send-otp-v2` / `verify-otp-v2` shipped. Body shape: `{ recipient, isPhone, otp?, orgId }`. Response shape mirrors v1 so the existing `VerifyOtpResponseModel` is reused. |
| **Course pricing v2 + create-order v2** | Done | Server-authoritative amount. Coupon-apply lives on a separate route the UI hasn't wired yet. |
| **Chat (SignalR + REST)** | Done | Group list, message history, send/delete, typing indicator. Chat-token bearer separated from main app token. |
| **Curriculum completion tracking** | Done for video + PDF | Threshold-based (≥75%). Session-deduped via `ContentCompletionService`. Other content types (image / zip / assignment-on-load) need the same plumbing. |
| **Multi-brand theming** | Done | `BrandingConfig` drives logo / app name / Razorpay merchant copy. Branch `dev` carries the Crinesta red-eye glyph. |
| **Native security posture** | Done for Android + iOS | FLAG_SECURE + iOS overlay + developer-mode / jailbreak audit + non-dismissible block screen. |

### Biggest technical challenges currently

1. **Upload progress UX is missing.** Retrofit-generated multipart calls don't surface `onSendProgress`. For large assignment files (or any future course-video upload from an instructor app), users see a binary spinner with no liveness signal. The clean fix is dropping certain upload endpoints to direct `Dio.post(..., onSendProgress: ...)` and exposing a `progress` state factory on the relevant cubit's freezed union. The 15 s `sendTimeout` will also need to be raised per-request.
2. **No 401 refresh / re-auth flow.** `AuthInterceptor` injects the bearer but doesn't recover on expiry. A 401 currently leaks as a `Failure.server(statusCode: 401)` to the cubit and the user sees the snackbar; the planned behaviour is to detect 401 in a response interceptor and route to `/login`, clearing the session.
3. **`api_client.g.dart` is hand-maintained.** `retrofit_generator` is incompatible with the current Dart SDK, so every new endpoint requires manually mirroring `ApiClient` changes into the generated file. This is the single biggest source of "it compiled but the call is wrong" papercuts.
4. **Backend JSON casing inconsistency.** Auth + assignment endpoints use PascalCase, courses + payments use camelCase. Models and `_extractServerMessage` tolerate both but every new field is a fresh decision point. A backend cleanup is outside our scope.
5. **iOS remote push is gated on a paid Apple Developer account.** Until that lands, every alert (including foreground FCM bridges) goes through `flutter_local_notifications`. Deep-linking from a notification tap works (foreground / warm-resume / cold-start are all covered by `FcmService` + `NotificationRouter`), but APNs delivery itself is not testable end-to-end.
6. **Subscriptions are not actually subscriptions.** Product copy uses "subscription" but the code models per-tier one-time charges. If recurring billing becomes a requirement, Razorpay Subscriptions API is a non-trivial integration — neither the order-create endpoint nor the cubit state machine is shaped for it today.
7. **No web target.** Piracy protection on web would need DRM + signed manifests, none of which is implemented. Current `BasicCaptureGuard` no-ops outside Android / iOS.
8. **Token refresh on FCM rotation.** `ProfileCubit.syncFcmToken` runs at cold start, but there's no listener on `FirebaseMessaging.instance.onTokenRefresh` that pushes the new token mid-session. Rotated tokens won't reach the backend until the next cold launch.

### Conventions worth remembering for any contributor

- **Cubit/Freezed `maybeWhen` is mandatory** — sealed-class `switch` is a known anti-pattern in this codebase.
- **Repositories return `Either<Failure, T>`.** Cubits `fold` and emit; pages never see raw exceptions.
- **`coursePurchasedId == 0` means preview.** Viewers skip completion tracking entirely.
- **Razorpay providers must live above the State that registers handlers** — see the comment in `view_demo_buy_now_row_widget.dart`.
- **`flutter pub run build_runner build --delete-conflicting-outputs`** after any freezed state change.
- **New endpoints**: edit `api_client.dart` AND `api_client.g.dart` (hand-maintained generated file).
