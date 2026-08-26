/// API Endpoint constants
///
/// This file contains all API endpoint paths used throughout the application.
/// Paths are relative to the BASE_URL defined in .env
library;

class ApiEndpoints {
  ApiEndpoints._();

  // ============================================================
  // AUTH
  // ============================================================
  static const String sendOtp = '/api/v1/send-otp';
  static const String verifyOtp = '/api/v1/verify-otp';

  // v2 OTP — same shape as v1 but recipient-agnostic (phone OR email)
  // and the discriminator rides on the `isPhone` query param.
  //   POST /api/v1/send-otp-v2?recipient=&isPhone=
  //   POST /api/v1/verify-otp-v2?recipient=&otp=&orgId=&isPhone=
  static const String sendOtpV2 = '/api/v1/send-otp-v2';
  static const String verifyOtpV2 = '/api/v1/verify-otp-v2';

  /// Exchange a (rotated) refresh token for a fresh access token.
  /// POST /api/v1/refresh-token   — **no Authorization header**
  /// Body:     { "refreshToken": String }
  /// Response: { "success": bool, "message": String,
  ///             "data": { "accessToken", "refreshToken", "expiresIn" } }
  ///
  /// Deliberately unauthenticated: the access token is expected to be dead
  /// by the time this is called, so requiring a live one would make the
  /// endpoint unreachable exactly when it is needed. The refresh token is
  /// the credential. A 401 here is final — it is the only response that
  /// justifies signing the learner out.
  static const String refreshToken = '/api/v1/refresh-token';

  /// Revoke the whole refresh-token family for this login.
  /// POST /api/v1/logout   — **no Authorization header**
  /// Body: { "refreshToken": String }
  ///
  /// Also unauthenticated, so a learner whose access token already expired
  /// can still end their session properly. Always answers 200: a token that
  /// is already gone is a session that is already over.
  static const String logout = '/api/v1/logout';

  /// Validate an org code before the auth flow.
  /// POST /api/v1/validate-org-code
  /// Body: { "orgCode": String }
  /// Response: { "message": String, "data": { "isValid": bool } }
  static const String validateOrgCode = '/api/v1/validate-org-code';

  // ============================================================
  // PROFILE
  // ============================================================
  static const String userProfile = '/api/v1/user-profile';

  // Dedicated FCM-token sync — JSON body { "fcmToken": "..." }.
  // Separate from the multipart user-profile update so a background
  // token refresh doesn't have to round-trip the whole profile.
  static const String updateFcm = '/api/v1/update-fcm';

  // ============================================================
  // DASHBOARD
  // ============================================================
  static const String dashboard = '/api/v1/dashboard';

  // ============================================================
  // COURSES
  // ============================================================
  static const String courseDetail = '/api/v1/course/{courseId}/v2';
  static const String coursesByTile = '/api/v1/course/tile/{tileId}';
  static const String coursesByCategory =
      '/api/v1/course/category/{categoryId}';
  static const String trendingCourses = '/api/v1/course/trending-courses';
  static const String courseReviews = '/api/v1/course/{courseId}/reviews';
  static const String saveCourseReview = '/api/v1/course/review';
  static const String continueCourse = '/api/v1/course/continue-course';
  static const String myCourses = '/api/v1/course/my-courses';
  static const String rewatchCourse = '/api/v1/course/{purchasedId}/re-watch';
  static const String courseCompletion = '/api/v1/course/completion';
  static const String transactionHistory = '/api/v1/course/transaction-history';
  // Returns a standalone HTML receipt document (not the usual JSON
  // envelope) for one of the caller's own payment transactions.
  // Body: { "transactionId": int }. See RECEIPT_API.md.
  static const String receiptDownload = '/api/v1/course/receipt/download';
  static const String courseCategories = '/api/v1/course/categories';

  // ============================================================
  // CERTIFICATES
  // Both endpoints take the learner from the JWT — never send a userId
  // or an org code, they are ignored server-side. See CERTIFICATE_API.md.
  // ============================================================
  /// Courses the learner has finished, each flagged with whether a
  /// certificate can be issued for it.
  static const String certificateCompleted = '/api/v1/certificate/completed';

  /// Returns the certificate itself as `application/pdf` (not the usual
  /// JSON envelope) plus an `X-Certificate-No` header. Error bodies are
  /// still JSON — but arrive as bytes, since the success path needs
  /// `ResponseType.bytes`.
  static const String certificateDownload =
      '/api/v1/certificate/download/{courseId}';

  static const String courseSearch = '/api/v1/course/search';
  static const String courseCatalog = '/api/v1/course/catalog';
  // pricing-v2 takes the course id AND a specific tier id as query params
  // (no path segment). The PriceId picks one entry from the detail's
  // `pricing.pricing[]` array. Query keys are PascalCase on the wire
  // (`CourseId` / `PriceId`) — wired as such in api_client.dart.
  static const String coursePricing = '/api/v1/course/pricing-v2';
  static const String courseAssignment =
      '/api/v1/course/{assignmentId}/assignment';
  static const String submitCourseAssignment = '/api/v1/course/assignment';

  // ============================================================
  // LIVE CLASSES (student-facing stream proxy)
  // ============================================================
  /// Resolves a signed HLS playback URL for a live class room. The
  /// path id is the roomId carried by the curriculum node's `url`
  /// field. Response: { success, message, data: { hlsUrl } }.
  /// Status semantics: 403 not enrolled, 404 not found, 410 not
  /// started / link expired, 503 streaming down.
  static const String liveClassPlayback =
      '/api/stream/live-classes/{roomId}/playback';

  /// Mints a short-lived StreamApi JWT so the student can open the
  /// SignalR class hub without ever holding the internal key.
  /// POST /api/stream/token → { success, message, data: { token } }.
  static const String streamToken = '/api/stream/token';

  /// Paginated chat backfill for a live class room. `beforeId` pages
  /// backwards; `limit` caps the page (default 30).
  /// GET /api/stream/live-classes/{roomId}/chat?beforeId=&limit=
  static const String liveClassChat =
      '/api/stream/live-classes/{roomId}/chat';

  // ============================================================
  // EXAM (student-only exam-taking flow — normal mode)
  //
  // Base route `api/v1/exam`. Every call carries a `phoneNumber` (query
  // on GETs, body field on POSTs) in addition to the JWT — the server
  // cross-checks it against the token's own account. Success responses
  // are wrapped `{ success, message, data }`. See EXAM_API.md.
  // ============================================================
  static const String examGate = '/api/v1/exam/{examId}/gate';
  static const String examStart = '/api/v1/exam/{examId}/start';
  static const String examPaper = '/api/v1/exam/attempt/{attemptId}/paper';
  // Competitive mode (one question at a time).
  static const String examQuestion =
      '/api/v1/exam/attempt/{attemptId}/question';
  static const String examAnswer = '/api/v1/exam/attempt/{attemptId}/answer';
  static const String examSave = '/api/v1/exam/attempt/{attemptId}/save';
  static const String examSubmit = '/api/v1/exam/attempt/{attemptId}/submit';
  static const String examResult = '/api/v1/exam/attempt/{attemptId}/result';
  static const String examHistory = '/api/v1/exam/{examId}/history';
  static const String examReattempt = '/api/v1/exam/{examId}/reattempt';

  // ============================================================
  // WEBINARS (public live classes)
  //
  // Both endpoints are scoped to the caller's organization *from the
  // JWT* — there is no org_code parameter and passing one does nothing.
  // The app only lists and describes webinars; joining happens on the
  // org's own website, opened in a webview from `shareLink`.
  // See WEBINAR_API.md.
  // ============================================================
  /// Live + upcoming webinars for the dashboard rail.
  /// GET /api/v1/webinars?pageNo=&pageSize=  (pageSize clamped to 50)
  /// Finished, cancelled and link-closed webinars are already excluded
  /// server-side, and the ordering (live first, then soonest) is
  /// authoritative — render in the order received.
  static const String webinars = '/api/v1/webinars';

  /// One webinar, superset of the list item — adds org branding, the
  /// gate state and `canJoin`. Unlike the list it still answers for
  /// ended / cancelled webinars, so a card that went stale in the
  /// learner's hand gets an explanation instead of a dead end.
  /// GET /api/v1/webinars/{slug}
  static const String webinarDetail = '/api/v1/webinars/{slug}';

  /// Takes the seat. No body — the learner is identified entirely from
  /// the account token, because in the app they are already a registered
  /// user. **Idempotent**: a second tap, a retry after a dropped
  /// connection, or rejoining tomorrow all return the same payload, so
  /// there is no "already joined" case to handle.
  ///
  /// Returns the same `data` shape as [webinarState], which is what lets
  /// the room route straight to the lobby or the player without a second
  /// call.
  ///
  /// POST /api/v1/webinars/{slug}/join
  static const String webinarJoinSeat = '/api/v1/webinars/{slug}/join';

  /// Lobby poll — `canWatch`, `startsInSeconds`, and a `message` written
  /// to be displayed verbatim. Poll every 10–15s while `canWatch` is
  /// false; never poll [webinarPlayback] hoping it starts working.
  /// GET /api/v1/webinars/{slug}/state
  static const String webinarState = '/api/v1/webinars/{slug}/state';

  /// Signed, time-limited HLS URL. Fetch when about to play, never
  /// cache. Calling it records attendance. 409 = not started (back to
  /// polling), 410 = finished, 403 = closed / seat removed.
  /// GET /api/v1/webinars/{slug}/playback
  static const String webinarPlayback = '/api/v1/webinars/{slug}/playback';

  /// Chat backfill, newest first. `beforeId` pages backwards.
  /// GET /api/v1/webinars/{slug}/chat?beforeId=&limit=
  static const String webinarChat = '/api/v1/webinars/{slug}/chat';

  /// Mints a short-lived **StreamApi** token for the class socket — a
  /// different service from this API. Mint per connection attempt; one
  /// fetched at page load is dead by the time a reconnect needs it.
  /// POST /api/v1/webinars/{slug}/hub-token
  static const String webinarHubToken = '/api/v1/webinars/{slug}/hub-token';

  /// P1 — a Razorpay order for a **paid** webinar. No request body: the
  /// webinar comes from the route and the amount from the database, so
  /// there is deliberately nothing here for a client to set.
  /// POST /api/v1/webinars/{slug}/create-order
  static const String webinarCreateOrder =
      '/api/v1/webinars/{slug}/create-order';

  /// P2 — **the seat is created here and nowhere else.** A completed
  /// Razorpay sheet is not a purchase until this returns `paid: true`.
  /// POST /api/v1/webinars/{slug}/verify-payment
  static const String webinarVerifyPayment =
      '/api/v1/webinars/{slug}/verify-payment';

  // ============================================================
  // NOTIFICATIONS
  // ============================================================
  static const String notifications = '/api/v1/notifications';
  static const String notificationReadStatus =
      '/api/v1/notifications/{notificationId}/read-status';

  // ============================================================
  // CHAT GROUPS
  // ============================================================
  static const String chatGroups = '/api/v1/chat-group';

  /// Returns the *dedicated chat token* used for every chat REST call
  /// and as the bearer for the SignalR hub. Distinct from the main
  /// access token. Authorised with the main access token. The `name`
  /// query parameter carries the student's display name so the
  /// backend can stamp it onto the token claims.
  static const String generateChatToken = '/api/v1/generate-token-v2';

  /// History for a chat room. The path id is the room id (string).
  /// Paged via `page` (1-indexed) and `pageSize` (default 50).
  static const String chatMessages = '/api/v1/chat-group/{groupId}/messages';

  /// Soft-delete a single message. The owning group id is sent as a
  /// query param so the backend can apply room-scoped permissions
  /// without re-reading the message row.
  static const String deleteChatMessage =
      '/api/v1/chat-group/messages/{messageId}';

  // ============================================================
  // DIRECT CHAT (1-to-1 student ↔ staff)
  //
  // Every call below is authorised with the *chat token* (the same JWT
  // minted by [generateChatToken] and used for the SignalR hub), passed
  // as an explicit `Authorization` header — not the main access token.
  //
  // `{conversationKey}` is an opaque server-issued string containing
  // `:` characters (e.g. `dm:CRINZA:e3:s142`). Callers pass it already
  // URL-encoded; never construct one client-side.
  // ============================================================

  /// The learner's DM inbox. Returns a **bare JSON array** of
  /// conversation cards, newest-activity first.
  static const String directConversations =
      '/api/v1/direct-chat/conversations';

  /// Staff the learner is allowed to message. Bare JSON array; each
  /// entry carries a precomputed `conversationKey`.
  static const String directDirectory = '/api/v1/direct-chat/directory';

  /// History for one thread. Same paged shape as [chatMessages] — the
  /// DM rows live in the same table, so `groupId` on each message
  /// carries the conversation key.
  static const String directMessages =
      '/api/v1/direct-chat/conversations/{conversationKey}/messages';

  /// Unread badge for a single thread, without opening a socket.
  static const String directUnreadCount =
      '/api/v1/direct-chat/conversations/{conversationKey}/unread-count';

  /// Clear a thread's badge over REST. `204 No Content`. Prefer the
  /// hub's `MarkDirectRead` while a room is open; this is the fallback
  /// when there's no live connection.
  static const String directMarkRead =
      '/api/v1/direct-chat/conversations/{conversationKey}/read';

  /// Soft-delete one of the learner's own messages. `204 No Content`.
  /// The owning thread travels as a query param so the backend can
  /// scope permissions without re-reading the message row.
  ///
  /// Removes the message for **both** sides, within 24 hours of
  /// sending. Not to be confused with [directClearConversation].
  static const String directDeleteMessage =
      '/api/v1/direct-chat/messages/{messageId}';

  /// Rewrite one of the learner's own text messages, within 2 minutes
  /// of sending. Body `{ conversationKey, message }`; returns the full
  /// updated message. Author-only — there is no staff override.
  static const String directEditMessage =
      '/api/v1/direct-chat/messages/{messageId}';

  /// Hide the thread's history from **this caller only** — a per-reader
  /// watermark, not a delete. The other party keeps everything.
  ///
  /// Returns `{ conversationKey, clearedUpToMessageId }`. This is a
  /// server call that persists across reinstalls; it is emphatically
  /// not a local "empty the list" UI state.
  static const String directClearConversation =
      '/api/v1/direct-chat/conversations/{conversationKey}/clear';

  // ============================================================
  // ORGANIZATION
  // ============================================================
  /// Returns org-specific info based on which flag is set to `true`:
  ///   ?whatsappNumber=true   → WhatsApp support number
  ///   ?termsAndCondition=true → pre-signed PDF URL for T&C
  ///   ?refundPolicy=true      → pre-signed PDF URL for refund policy
  static const String organizationInfo = '/api/v1/organization-info';

  /// Returns the org's Play Store / App Store URL for "Rate this app".
  /// GET /api/v1/app-rating-url?deviceType=android|ios
  /// The org is resolved from the JWT — `deviceType` is the only param.
  ///
  /// NOTE: the backend doc listed the controller route as
  /// `api/v1/UserAuth/app-rating-url`, but every other endpoint this app
  /// hits is a flat `/api/v1/<action>` with no controller segment, and
  /// the `UserAuth` path 404s in production — so we use the flat form.
  static const String appRatingUrl = '/api/v1/app-rating-url';

  // ============================================================
  // WORKSHOP PASS
  // ============================================================
  // The entry ticket for a paid in-person workshop. Not a certificate:
  // it exists the moment the workshop is paid for (not on completion),
  // it is keyed by the webinar's `publicSlug`, and it is meant to be
  // held up at a door rather than filed away.
  //
  // Neither call takes a user id or an org code — both come from the
  // JWT, so there is no field an attendee could edit to reach somebody
  // else's pass.
  // ============================================================
  /// The pass itself, as JSON carrying a **complete standalone HTML
  /// document** (`data.html`) plus the raw fields behind it. Fetching is
  /// also what *issues* the pass, and it is idempotent: the pass number
  /// and the QR are frozen at the first fetch and never change.
  ///
  /// Fast (~100–300ms) — no browser is launched. Do **not** put the
  /// download call's long receive timeout on this one.
  /// GET /api/v1/workshop-pass/{slug}
  static const String workshopPass = '/api/v1/workshop-pass/{slug}';

  /// Everything this learner booked, past and upcoming, with their pass
  /// and whether they turned up. See MY_WEBINARS_API.md.
  ///
  /// The pass endpoints are keyed on a slug, so this is what makes a
  /// pass findable once the app is no longer holding the slug from a
  /// purchase. `pageSize` is clamped to 1..50 server-side, so the
  /// returned value is read back rather than assumed.
  ///
  /// An empty history is a 200 with `total: 0`, never a 404.
  /// GET /api/v1/workshop-pass/my?pageNo=&pageSize=
  static const String myWebinars = '/api/v1/workshop-pass/my';

  /// The same pass as a 720×340pt PDF card — `application/pdf`, not the
  /// usual JSON envelope, so this goes through raw Dio with
  /// `ResponseType.bytes`.
  ///
  /// Prefer the absolute `downloadUrl` the pass payload already carries;
  /// this is the fallback for when it comes back empty.
  ///
  /// The first call after an API restart launches Chromium server-side
  /// and takes 2–5s.
  /// GET /api/v1/workshop-pass/{slug}/download
  static const String workshopPassDownload =
      '/api/v1/workshop-pass/{slug}/download';

  // ============================================================
  // PAYMENTS
  // ============================================================
  static const String createOrder = '/api/v1/payments/create-order-v2';
  static const String verifyPayment = '/api/v1/payments/verify-payment';
}
