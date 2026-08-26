import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/widgets/splash_screen.dart';
import 'package:nexora/features/auth/presentation/pages/login_page.dart';
import 'package:nexora/features/auth/presentation/pages/org_code_page.dart';
import 'package:nexora/features/auth/presentation/pages/otp_page.dart';
import 'package:nexora/features/auth/presentation/pages/setup_profile_page.dart';
import 'package:nexora/features/auth/presentation/bloc/org_code_cubit.dart';
import 'package:nexora/features/auth/presentation/bloc/otp_cubit.dart';
import 'package:nexora/features/home/presentation/bloc/home_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/continue_courses_cubit.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinars_cubit.dart';
import 'package:nexora/features/home/presentation/pages/home_page.dart';
import 'package:nexora/features/notification/presentation/bloc/notification_cubit.dart';
import 'package:nexora/features/notification/presentation/pages/notification_page.dart';
import 'package:nexora/features/courses/presentation/pages/course_detail_page.dart';
import 'package:nexora/features/courses/presentation/pages/search_page.dart';
import 'package:nexora/features/chats/presentation/pages/chat_room_page.dart';
import 'package:nexora/features/direct_chat/presentation/pages/direct_chat_inbox_page.dart';
import 'package:nexora/features/direct_chat/presentation/pages/direct_chat_room_page.dart';
import 'package:nexora/features/assignment/presentation/pages/assignment_page.dart';
import 'package:nexora/features/exam/presentation/pages/exam_page.dart';
import 'package:nexora/features/courses/presentation/pages/folder_content_page.dart';
import 'package:nexora/features/courses/presentation/pages/pdf_viewer_page.dart';
import 'package:nexora/features/courses/presentation/pages/image_viewer_page.dart';
import 'package:nexora/features/courses/presentation/bloc/live_now_cubit.dart';
import 'package:nexora/features/courses/presentation/pages/live_class_page.dart';
import 'package:nexora/features/courses/presentation/pages/video_player_page.dart';
import 'package:nexora/features/courses/presentation/folder_navigation_cache.dart';
import 'package:nexora/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:nexora/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:nexora/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:nexora/features/transaction/presentation/pages/transaction_history_page.dart';
import 'package:nexora/features/certificate/data/models/completed_course_model.dart';
import 'package:nexora/features/certificate/presentation/pages/certificate_preview_page.dart';
import 'package:nexora/features/certificate/presentation/pages/certificates_page.dart';
import 'package:nexora/features/webinar/presentation/pages/webinar_detail_page.dart';
import 'package:nexora/features/webinar/presentation/pages/webinar_room_page.dart';
import 'package:nexora/features/webinar/presentation/pages/webinars_page.dart';
import 'package:nexora/features/workshop_pass/data/models/workshop_pass_model.dart';
import 'package:nexora/features/workshop_pass/presentation/pages/workshop_pass_page.dart';
import 'package:nexora/features/workshop_pass/presentation/pages/workshop_pass_pdf_page.dart';
import 'package:nexora/features/catalog/presentation/pages/catalog_page.dart';
import 'package:nexora/features/courses/data/models/course_filter_models.dart';
import 'package:nexora/features/catalog/presentation/pages/category_list_page.dart';
import 'package:nexora/features/courses/presentation/pages/document_viewer_page.dart';
import 'package:nexora/features/workshop_pass/presentation/pages/my_bookings_page.dart';
import 'app_routes.dart';

/// App router configuration using go_router
///
/// Define your app routes here using GoRoute.
/// Example:
/// ```dart
/// GoRoute(
///   path: AppRoutes.home,
///   name: 'home',
///   builder: (context, state) => const HomeScreen(),
/// ),
/// ```
class AppRouter {
  AppRouter._();

  /// Initial route (splash screen or onboarding)
  static const String initialRoute = AppRoutes.splash;

  /// Maps the `tab` query param of `/courses/detail` to a tab index —
  /// `about` / `content` / `reviews`, or a plain index. Anything missing
  /// or unrecognised falls back to About (0), the historical default.
  static int _courseTabIndex(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'content':
      case 'curriculum':
        return 1;
      case 'reviews':
        return 2;
      case 'about':
        return 0;
      default:
        return int.tryParse(raw ?? '') ?? 0;
    }
  }

  /// Router configuration
  static final GoRouter router = GoRouter(
    initialLocation: initialRoute,
    debugLogDiagnostics: true,
    routes: [
      // ============================================
      // AUTH ROUTES
      // ============================================
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const _OnboardingPlaceholder(),
      ),
      GoRoute(
        path: AppRoutes.orgCode,
        name: 'org-code',
        builder: (context, state) => BlocProvider(
          create: (_) => sl<OrgCodeCubit>(),
          child: const OrgCodePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        name: 'otp',
        builder: (context, state) {
          // v2 routing — supports both phone (?phone=&countryCode=)
          // and email (?email=) recipients. `isPhone` defaults to
          // true when no email param is present, keeping the legacy
          // /otp?phone=…&countryCode=… callers working unchanged.
          final phoneNumber = state.uri.queryParameters['phone'] ?? '';
          final countryCode = state.uri.queryParameters['countryCode'] ?? '+91';
          final email = state.uri.queryParameters['email'] ?? '';
          final isPhoneRaw = state.uri.queryParameters['isPhone']
              ?.toLowerCase();
          final isPhone = isPhoneRaw == null
              ? email.isEmpty
              : isPhoneRaw != 'false';
          return BlocProvider(
            create: (context) => sl<OtpCubit>(),
            child: OtpPage(
              phoneNumber: phoneNumber,
              countryCode: countryCode,
              email: email,
              isPhone: isPhone,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const _RegisterPlaceholder(),
      ),
      GoRoute(
        path: AppRoutes.setupProfile,
        name: 'setup-profile',
        builder: (context, state) {
          // v2 routing — supports both phone-verified (phone= + countryCode=)
          // and email-verified (email=) entry. isPhone defaults to
          // "no email param present" so legacy callers stay working.
          final phoneNumber = state.uri.queryParameters['phone'] ?? '';
          final countryCode = state.uri.queryParameters['countryCode'] ?? '+91';
          final email = state.uri.queryParameters['email'] ?? '';
          final isPhoneRaw = state.uri.queryParameters['isPhone']
              ?.toLowerCase();
          final isPhone = isPhoneRaw == null
              ? email.isEmpty
              : isPhoneRaw != 'false';
          return SetupProfilePage(
            phoneNumber: phoneNumber,
            countryCode: countryCode,
            email: email,
            isPhone: isPhone,
          );
        },
      ),

      // ============================================
      // MAIN APP ROUTE (with bottom navigation)
      // ============================================
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),

      // ============================================
      // FEATURE ROUTES (nested under main if needed)
      // ============================================
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        // HomePage reads four cubits, not one. The Dashboard normally
        // owns all four (so it can silent-refresh them when the Home
        // tab is re-entered); this route is the standalone/deep-link
        // entry, and it has to provide the same set or the page throws
        // looking one of them up.
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<HomeCubit>()),
            BlocProvider(create: (_) => sl<ContinueCoursesCubit>()..load()),
            BlocProvider(create: (_) => sl<WebinarsCubit>()..load()),
            BlocProvider(create: (_) => sl<LiveNowCubit>()..load()),
          ],
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.courseList,
        name: 'course-list',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final title = q['title'] ?? 'Courses';
          final tileId = int.tryParse(q['tileId'] ?? '');
          final categoryId = int.tryParse(q['categoryId'] ?? '');
          if (tileId == null && categoryId == null) {
            return const Scaffold(
              body: Center(child: Text('Missing tileId or categoryId')),
            );
          }
          // Redirect/Render CatalogPage instead of CourseListPage to unify
          // everything to the new dynamic Catalog screen.
          return CatalogPage(
            tileId: tileId,
            categoryId: categoryId,
            title: title,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.courseSearch,
        name: 'course-search',
        builder: (context, state) =>
            searchPageFromQuery(state.uri.queryParameters),
      ),
      GoRoute(
        path: AppRoutes.chatRoom,
        name: 'chat-room',
        builder: (context, state) =>
            chatRoomPageFromQuery(state.uri.queryParameters),
      ),
      GoRoute(
        path: AppRoutes.directChatInbox,
        name: 'direct-chat-inbox',
        builder: (context, state) => const DirectChatInboxPage(),
      ),
      GoRoute(
        path: AppRoutes.directChatRoom,
        name: 'direct-chat-room',
        builder: (context, state) =>
            directChatRoomPageFromQuery(state.uri.queryParameters),
      ),
      GoRoute(
        path: AppRoutes.courseDetail,
        name: 'course-detail',
        builder: (context, state) {
          final courseId = int.tryParse(
            state.uri.queryParameters['courseId'] ?? '',
          );
          if (courseId == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid course id')),
            );
          }
          // Optional title hint (e.g. ctaName from a banner tap).
          // Displayed immediately in the AppBar while the API loads.
          final courseTitle = state.uri.queryParameters['title'];
          return CourseDetailPage(
            courseId: courseId,
            courseTitle: courseTitle,
            initialTabIndex: _courseTabIndex(state.uri.queryParameters['tab']),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.folderContent,
        name: 'folder-content',
        builder: (context, state) {
          // The pushing widget seeds [FolderNavigationCache] with the
          // content tree and only the folderId travels in the URL — keeps
          // go_router happy while preserving the nested folder data.
          final folderId = state.uri.queryParameters['folderId'];
          final courseId =
              int.tryParse(state.uri.queryParameters['courseId'] ?? '') ?? 0;
          final coursePurchasedId =
              int.tryParse(
                state.uri.queryParameters['coursePurchasedId'] ?? '',
              ) ??
              0;
          final folder = folderId == null
              ? null
              : FolderNavigationCache.peek(folderId);
          if (folder == null) {
            return const Scaffold(
              body: Center(child: Text('Folder not found')),
            );
          }
          final activateWatermark =
              state.uri.queryParameters['activateWatermark'] == 'true';
          return FolderContentPage(
            folder: folder,
            courseId: courseId,
            coursePurchasedId: coursePurchasedId,
            activateWatermark: activateWatermark,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.documentViewer,
        name: 'document-viewer',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Document';
          final url = state.uri.queryParameters['url'] ?? '';
          if (url.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('No document URL provided')),
            );
          }
          return DocumentViewerPage(title: title, url: url);
        },
      ),
      GoRoute(
        path: AppRoutes.pdfViewer,
        name: 'pdf-viewer',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Document';
          final url = state.uri.queryParameters['url'] ?? '';
          if (url.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('No PDF URL provided')),
            );
          }
          // `extra` is `Object?` and many callers don't pass it (module
          // card, course detail). Read it defensively — only honour
          // `showActions` when extra is a Map and the value is a bool;
          // otherwise default to true so behavior matches the previous
          // single-arg push.
          final extra = state.extra;
          final showActions = (extra is Map && extra['showActions'] is bool)
              ? extra['showActions'] as bool
              : true;
          // Optional completion tracking — viewer fires the /completion
          // POST at ≥75% page progress when both ids are present.
          final coursePurchasedId =
              int.tryParse(
                state.uri.queryParameters['coursePurchasedId'] ?? '',
              ) ??
              0;
          final nodeId = state.uri.queryParameters['nodeId'] ?? '';
          return PdfViewerPage(
            title: title,
            url: url,
            showActions: showActions,
            coursePurchasedId: coursePurchasedId,
            nodeId: nodeId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.imageViewer,
        name: 'image-viewer',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Image';
          final url = state.uri.queryParameters['url'] ?? '';
          if (url.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('No image URL provided')),
            );
          }
          final coursePurchasedId =
              int.tryParse(
                state.uri.queryParameters['coursePurchasedId'] ?? '',
              ) ??
              0;
          final nodeId = state.uri.queryParameters['nodeId'] ?? '';
          return ImageViewerPage(
            title: title,
            url: url,
            coursePurchasedId: coursePurchasedId,
            nodeId: nodeId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.videoPlayer,
        name: 'video-player',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Video';
          final url = state.uri.queryParameters['url'] ?? '';
          if (url.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('No video URL provided')),
            );
          }
          final coursePurchasedId =
              int.tryParse(
                state.uri.queryParameters['coursePurchasedId'] ?? '',
              ) ??
              0;
          final nodeId = state.uri.queryParameters['nodeId'] ?? '';
          final activateWatermark =
              state.uri.queryParameters['activateWatermark'] == 'true';
          return VideoPlayerPage(
            title: title,
            url: url,
            coursePurchasedId: coursePurchasedId,
            nodeId: nodeId,
            activateWatermark: activateWatermark,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.liveClass,
        name: 'live-class',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Live Class';
          // `url` carries the roomId (mirrors how assignment/exam carry
          // their ids in the node's url field).
          final roomId = state.uri.queryParameters['url'] ?? '';
          if (roomId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('No live class id provided')),
            );
          }
          final courseId =
              int.tryParse(state.uri.queryParameters['courseId'] ?? '') ?? 0;
          final coursePurchasedId =
              int.tryParse(
                state.uri.queryParameters['coursePurchasedId'] ?? '',
              ) ??
              0;
          final nodeId = state.uri.queryParameters['nodeId'] ?? '';
          final activateWatermark =
              state.uri.queryParameters['activateWatermark'] == 'true';
          final scheduledRaw = state.uri.queryParameters['scheduledAt'];
          final scheduledAt = scheduledRaw == null
              ? null
              : DateTime.tryParse(scheduledRaw);
          return LiveClassPage(
            title: title,
            roomId: roomId,
            courseId: courseId,
            coursePurchasedId: coursePurchasedId,
            nodeId: nodeId,
            activateWatermark: activateWatermark,
            scheduledAt: scheduledAt,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.assignment,
        name: 'assignment',
        builder: (context, state) {
          final assignmentId = int.tryParse(
            state.uri.queryParameters['assignmentId'] ?? '',
          );
          final courseId = int.tryParse(
            state.uri.queryParameters['courseId'] ?? '',
          );
          final nodeId = state.uri.queryParameters['nodeId'] ?? '';
          // Optional — only fired by AssignmentPage when present.
          final coursePurchasedId =
              int.tryParse(
                state.uri.queryParameters['coursePurchasedId'] ?? '',
              ) ??
              0;
          if (assignmentId == null || courseId == null || nodeId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Invalid assignment id')),
            );
          }
          return AssignmentPage(
            assignmentId: assignmentId,
            courseId: courseId,
            nodeId: nodeId,
            coursePurchasedId: coursePurchasedId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.exam,
        name: 'exam',
        builder: (context, state) {
          final examId = int.tryParse(
            state.uri.queryParameters['examId'] ?? '',
          );
          final courseId = int.tryParse(
            state.uri.queryParameters['courseId'] ?? '',
          );
          final nodeId = state.uri.queryParameters['nodeId'] ?? '';
          final coursePurchasedId =
              int.tryParse(
                state.uri.queryParameters['coursePurchasedId'] ?? '',
              ) ??
              0;
          if (examId == null || examId == 0 || nodeId.isEmpty) {
            return const Scaffold(body: Center(child: Text('Invalid exam id')));
          }
          return ExamPage(
            examId: examId,
            nodeId: nodeId,
            courseId: courseId ?? 0,
            coursePurchasedId: coursePurchasedId,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        name: 'edit-profile',
        builder: (context, state) {
          // Pulls the live profile out of the global ProfileCubit so we
          // don't need to round-trip a complex object through go_router's
          // `extra:` (which warns about non-serializable payloads).
          final cubitState = sl<ProfileCubit>().state;
          final profile = cubitState.maybeWhen(
            loaded: (p) => p,
            updated: (p) => p,
            updating: (p) => p,
            orElse: () => null,
          );
          if (profile == null) {
            return const Scaffold(
              body: Center(child: Text('Profile data missing')),
            );
          }
          return EditProfilePage(profile: profile);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => BlocProvider(
          create: (context) => sl<NotificationCubit>(),
          child: const NotificationPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const _SettingsPlaceholder(),
      ),

      GoRoute(
        path: AppRoutes.transactionHistory,
        name: 'transaction-history',
        builder: (context, state) {
          return TransactionHistoryPage();
        },
      ),
      GoRoute(
        path: AppRoutes.myBookings,
        name: 'my-bookings',
        builder: (context, state) => const MyBookingsPage(),
      ),
      GoRoute(
        path: AppRoutes.certificates,
        name: 'certificates',
        builder: (context, state) => const CertificatesPage(),
      ),
      GoRoute(
        path: AppRoutes.certificatePreview,
        name: 'certificate-preview',
        builder: (context, state) {
          // Only ever reached via `openCertificate`, which pushes a
          // freshly downloaded file. A deep link (or a hot restart that
          // drops `extra`) lands here with nothing to show — send the
          // learner to the list rather than crashing on a null cast.
          final certificate = state.extra;
          if (certificate is! DownloadedCertificate) {
            return const CertificatesPage();
          }
          return CertificatePreviewPage(certificate: certificate);
        },
      ),
      GoRoute(
        path: AppRoutes.webinars,
        name: 'webinars',
        builder: (context, state) => const WebinarsPage(),
      ),
      GoRoute(
        path: AppRoutes.webinarDetail,
        name: 'webinar-detail',
        builder: (context, state) {
          final slug = state.uri.queryParameters['slug'] ?? '';
          // An empty slug can only come from a malformed link — the page
          // says so itself rather than firing a request that would 400.
          return WebinarDetailPage(slug: slug);
        },
      ),
      GoRoute(
        path: AppRoutes.webinarRoom,
        name: 'webinar-room',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final slug = q['slug'] ?? '';
          final roomId = q['roomId'] ?? '';
          // Without a slug there is nothing to join; the Join button
          // always supplies one, but a hand-typed link may not.
          if (slug.isEmpty) return const WebinarsPage();
          final thumbnailUrl = q['thumbnailUrl'];
          final educatorName = q['educatorName'];
          return WebinarRoomPage(
            slug: slug,
            roomId: roomId,
            title: q['title'] ?? 'Webinar',
            thumbnailUrl: (thumbnailUrl?.isEmpty ?? true) ? null : thumbnailUrl,
            educatorName: (educatorName?.isEmpty ?? true) ? null : educatorName,
            // Decides whether a meeting link may be shown and copied, so
            // an absent or unreadable value is treated as paid: the
            // failure that costs a free webinar its Copy button is much
            // cheaper than the one that hands a paid seat away.
            isFree: q['isFree'] == 'true',
            // Absent or unreadable falls back to `true`, which is the
            // old behaviour: connect first, then swap. Only a value we
            // can actually read skips the flash.
            isStream: q['isStream'] != 'false',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.workshopPass,
        name: 'workshop-pass',
        builder: (context, state) {
          final slug = state.uri.queryParameters['slug'] ?? '';
          // Without a slug there is no workshop to issue a pass for.
          // Every entry point supplies one; a hand-typed link may not.
          if (slug.isEmpty) return const WebinarsPage();
          final title = state.uri.queryParameters['title'];
          return WorkshopPassPage(
            slug: slug,
            workshopTitle: (title?.isEmpty ?? true) ? null : title,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.workshopPassPdf,
        name: 'workshop-pass-pdf',
        builder: (context, state) {
          // Only ever reached from the pass screen's Save action, which
          // pushes a freshly written file. A deep link (or a hot restart
          // that drops `extra`) lands here with nothing to show — send
          // them back to the list rather than crashing on a null cast.
          final pass = state.extra;
          if (pass is! DownloadedPass) return const WebinarsPage();
          return WorkshopPassPdfPage(pass: pass);
        },
      ),
      GoRoute(
        path: AppRoutes.catalog,
        name: 'catalog',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Course Catalog';
          final searchQuery = state.uri.queryParameters['searchQuery'];
          final categoryId = int.tryParse(
            state.uri.queryParameters['categoryId'] ?? '',
          );
          final tileId = int.tryParse(
            state.uri.queryParameters['tileId'] ?? '',
          );
          final courseStatusType = int.tryParse(
            state.uri.queryParameters['courseStatusType'] ?? '',
          );
          final courseType = state.uri.queryParameters['courseType'];
          final sortByRaw = state.uri.queryParameters['sortBy'];
          CatalogSortBy? sortBy;
          if (sortByRaw != null) {
            sortBy = CatalogSortBy.values.firstWhere(
              (e) => e.name == sortByRaw || e.apiValue == sortByRaw,
              orElse: () => CatalogSortBy.all,
            );
          }
          return CatalogPage(
            title: title,
            searchQuery: searchQuery,
            categoryId: categoryId,
            tileId: tileId,
            courseStatusType: courseStatusType,
            courseType: courseType,
            sortBy: sortBy,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.categories,
        name: 'categories',
        builder: (context, state) => const CategoryListPage(),
      ),

      // ============================================
      // 404 NOT FOUND
      // ============================================
      GoRoute(
        path: AppRoutes.notFound,
        name: 'not_found',
        builder: (context, state) => const _NotFoundPlaceholder(),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundPlaceholder(),
  );
}

// ============================================
// PLACEHOLDER WIDGETS (Replace with actual screens)
// ============================================

class _OnboardingPlaceholder extends StatelessWidget {
  const _OnboardingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Onboarding Screen - Implement me')),
    );
  }
}

class _RegisterPlaceholder extends StatelessWidget {
  const _RegisterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Register Screen - Implement me')),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Settings Screen - Implement me')),
    );
  }
}

class _NotFoundPlaceholder extends StatelessWidget {
  const _NotFoundPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('404 - Page Not Found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// ROUTER EXTENSIONS (Helper methods)
// ============================================

/// Extension on BuildContext for easy navigation
extension RouterContext on BuildContext {
  /// Navigate to a route by name
  void goNamed(String name, {Map<String, String> pathParameters = const {}}) {
    GoRouter.of(this).goNamed(name, pathParameters: pathParameters);
  }

  /// Push a route by name
  void pushNamed(String name, {Map<String, String> pathParameters = const {}}) {
    GoRouter.of(this).pushNamed(name, pathParameters: pathParameters);
  }

  /// Go back
  void pop<T>([T? result]) {
    GoRouter.of(this).pop(result);
  }
}
