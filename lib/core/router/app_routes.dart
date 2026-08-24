/// App route paths constants
///
/// Defines all route paths used throughout the application.
/// Use these constants instead of hardcoded strings to avoid typos
/// and make route management easier.
class AppRoutes {
  AppRoutes._();

  // ============================================
  // AUTH ROUTES
  // ============================================
  /// Splash screen route
  static const String splash = '/splash';

  /// Onboarding screen route
  static const String onboarding = '/onboarding';

  ///  Org Code entry screen — shown before login when ORG_ID=CRINZA in .env.
  static const String orgCode = '/org-code';

  /// Login screen route
  static const String login = '/login';

  /// OTP verification screen route
  static const String otp = '/otp';

  /// Register/Sign up screen route
  static const String register = '/register';

  /// Setup Profile screen route (shown when user is not registered)
  static const String setupProfile = '/setup-profile';

  // ============================================
  // ALWAYS-LIGHT ROUTES
  // ============================================

  /// Routes that paint in the light palette regardless of the user's
  /// theme preference.
  ///
  /// These three screens are composited over a **fixed light background
  /// image** (the lavender gradient in `AppImages.loginBackground`).
  /// There is no dark counterpart of that artwork, so under the dark
  /// palette a dark glass sheet and pale text land on top of a bright
  /// picture — the screen reads as broken rather than as dark mode.
  ///
  /// This is exactly the set of routes whose pages draw
  /// `AppImages.loginBackground`; if a screen stops using that artwork,
  /// or a new one starts, this set should move with it.
  ///
  /// `setup-profile` is deliberately absent — it is part of the same
  /// flow but renders on a normal themed scaffold, so it honours the
  /// user's choice like the rest of the app.
  static const Set<String> alwaysLightRoutes = {orgCode, login, otp};

  /// Whether [location] is one of [alwaysLightRoutes].
  ///
  /// Compares the path only, since real locations arrive carrying query
  /// strings — `/otp?phone=…&isPhone=true` has to match `/otp`.
  static bool isAlwaysLight(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    return alwaysLightRoutes.contains(path);
  }

  // ============================================
  // MAIN APP ROUTES
  // ============================================
  /// Home screen route
  static const String home = '/home';

  /// Main app screen with bottom navigation
  static const String dashboard = '/dashboard';

  /// Chats screen route
  static const String chats = '/chats';

  /// Single chat room — requires `groupId` (SignalR room id) plus
  /// `groupName` and optional `canUserReply` query params so the page
  /// can render the AppBar / input-bar without re-fetching the parent
  /// group payload.
  static const String chatRoom = '/chats/room';

  /// Personal-chat inbox — the learner's private 1-to-1 threads with
  /// staff. Entered from the Profile screen's "Personal Chat" tile.
  static const String directChatInbox = '/chats/direct';

  /// Single personal-chat thread — requires `conversationKey` plus
  /// `otherUserName` and optional `otherUserAvatarUrl` / `isBlocked`
  /// query params so the room can render its AppBar and composer
  /// without re-fetching the inbox card.
  static const String directChatRoom = '/chats/direct/room';

  /// Courses screen route
  static const String courses = '/courses';

  /// Course list by category route
  static const String courseList = '/courses/category';

  /// Course search route — accepts optional `searchQuery` and `isPaid`
  /// query params to seed the search field on open.
  static const String courseSearch = '/courses/search';

  /// Edit profile route — renders the setup-profile UI pre-populated
  /// with the current user's data.
  static const String editProfile = '/profile/edit';

  /// Course detail route
  static const String courseDetail = '/courses/detail';

  /// Folder content route
  static const String folderContent = '/courses/folder';

  /// PDF viewer route
  static const String pdfViewer = '/courses/pdf';

  /// Document viewer route
  static const String documentViewer = '/courses/document';

  /// Video player route
  static const String videoPlayer = '/courses/video';

  /// Image viewer route — used for image curriculum nodes.
  static const String imageViewer = '/courses/image';

  /// Assignment screen — accepts `assignmentId` (path id for the GET,
  /// parsed from the curriculum node's `url` field), `courseId` (sent
  /// alongside on submit), `nodeId` (jsonNodeId for completion + submit),
  /// and optional `coursePurchasedId` (enables completion tracking).
  static const String assignment = '/courses/assignment';

  /// Exam-taking screen — accepts `examId` (path id parsed from the
  /// curriculum node's `url` field), `nodeId` (jsonNodeId for completion),
  /// `courseId`, and optional `coursePurchasedId` (enables completion
  /// tracking).
  static const String exam = '/courses/exam';

  /// Live class player — accepts `title`, `url` (the live-class **roomId**,
  /// not an HLS URL — the page resolves playback through the stream
  /// proxy), `courseId`, `nodeId`, optional `coursePurchasedId` (enables
  /// completion tracking) and `activateWatermark`.
  static const String liveClass = '/courses/live';

  /// Profile screen route
  static const String profile = '/profile';

  /// Notifications screen route
  static const String notifications = '/notifications';

  /// Settings screen route
  static const String settings = '/settings';

  /// Transaction history screen route
  static const String transactionHistory = '/transaction-history';

  /// Course certificates screen route — lists completed courses and
  /// downloads the certificate for the ones that issue one.
  static const String certificates = '/certificates';

  /// In-app viewer for an already-downloaded certificate PDF. Takes the
  /// `DownloadedCertificate` as go_router `extra:` — the file lives on
  /// disk, so there is no URL to carry in the path.
  static const String certificatePreview = '/certificates/preview';

  /// All webinars — the full list behind Home's "View All".
  static const String webinars = '/webinars';

  /// Webinar detail — requires a `slug` query param (webinars have no
  /// numeric id; the slug is the key for every webinar call).
  static const String webinarDetail = '/webinars/detail';

  /// The webinar room — lobby, player and chat, all in the app. Takes
  /// `slug` (every webinar call's key), `roomId` (the chat socket room),
  /// `title`, and optional `thumbnailUrl` / `educatorName` carried over
  /// so the lobby has something to show while waiting.
  ///
  /// Joining is a native call on the account token; `shareLink` is only
  /// ever handed to the share sheet, never opened as the way in.
  static const String webinarRoom = '/webinars/room';

  /// My Bookings — every webinar and workshop this learner signed up
  /// for, and the way back to a workshop pass once the app is no longer
  /// holding the slug from the purchase that issued it.
  static const String myBookings = '/my-bookings';

  /// The entry pass for a paid in-person workshop. Takes `slug` (the
  /// workshop's `publicSlug` — the key for every pass call) and an
  /// optional `title`, carried purely so the screen has something to
  /// name while the first fetch is in flight.
  ///
  /// Gated by `showsWorkshopPass`, which mirrors the server's own check,
  /// so the route is only ever reached where a pass exists.
  static const String workshopPass = '/workshops/pass';

  /// In-app viewer for an already-saved pass PDF. Takes the
  /// `DownloadedPass` as go_router `extra:` — the file lives on disk, so
  /// there is no URL to carry in the path.
  static const String workshopPassPdf = '/workshops/pass/pdf';

  /// Catalog screen route
  static const String catalog = '/catalog';

  /// Categories listing route
  static const String categories = '/catalog/categories';

  // ============================================
  // UTILITY ROUTES
  // ============================================
  /// 404 Not Found screen route
  static const String notFound = '/404';
}
