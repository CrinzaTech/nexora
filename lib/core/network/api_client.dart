import 'dart:io';

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'api_endpoints.dart';

part 'api_client.g.dart';

/// Retrofit API client.
///
/// NOTE: api_client.g.dart is maintained manually (retrofit_generator is excluded
/// due to SDK incompatibility). Regenerate manually when adding new endpoints.
@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String? baseUrl}) = _ApiClient;

  // ============================================================
  // AUTH — Send OTP
  // GET /api/v1/send-otp?mobileNumber=xxx
  // ============================================================
  @GET(ApiEndpoints.sendOtp)
  Future<Map<String, dynamic>> sendOtp(
    @Query('mobileNumber') String mobileNumber,
  );

  // ============================================================
  // AUTH — Verify OTP
  // GET /api/v1/verify-otp?mobileNumber=xxx&otp=xxx&orgId=xxx
  //                        &device_key_param=<stable-device-id>
  // ============================================================
  @GET(ApiEndpoints.verifyOtp)
  Future<Map<String, dynamic>> verifyOtp(
    @Query('mobileNumber') String mobileNumber,
    @Query('otp') String otp,
    @Query('orgId') String? orgId,
    @Query('device_key_param') String? deviceKeyParam,
  );

  // ============================================================
  // AUTH — Send OTP (v2)
  // POST /api/v1/send-otp-v2
  // Headers: Content-Type: application/json
  // Body: { "recipient": String, "isPhone": bool }
  //
  // Recipient is either an E.164 phone number (isPhone=true) or an
  // email address (isPhone=false). The backend routes delivery
  // accordingly. JSON body — not query params.
  // ============================================================
  @POST(ApiEndpoints.sendOtpV2)
  Future<Map<String, dynamic>> sendOtpV2(@Body() Map<String, dynamic> body);

  // ============================================================
  // AUTH — Verify OTP (v2)
  // POST /api/v1/verify-otp-v2
  // Headers: Content-Type: application/json
  // Body: { "recipient": String, "isPhone": bool, "otp": String,
  //         "orgId": String, "device_key_param": String }
  //
  // Same `recipient` + `isPhone` contract as v2 send. Response
  // shape mirrors v1 (success / accessToken / isUserAlreadyExist),
  // so existing `VerifyOtpResponseModel` deserialiser is reused.
  // `device_key_param` is a stable hardware-level device identifier
  // (Android: SSAID / iOS: IDFV) sent on every verification call.
  // ============================================================
  @POST(ApiEndpoints.verifyOtpV2)
  Future<Map<String, dynamic>> verifyOtpV2(@Body() Map<String, dynamic> body);

  // ============================================================
  // AUTH — Validate Org Code
  // POST /api/v1/validate-org-code
  // Body: { "orgCode": String }
  // Response: { "message": String, "data": { "isValid": bool } }
  // ============================================================
  @POST(ApiEndpoints.validateOrgCode)
  Future<Map<String, dynamic>> validateOrgCode(
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // PROFILE — Get User Profile
  // GET /api/v1/user-profile
  // ============================================================
  @GET(ApiEndpoints.userProfile)
  Future<Map<String, dynamic>> getUserProfile();

  // ============================================================
  // PROFILE — Update User Profile
  // PUT /api/v1/user-profile (multipart form data)
  // ============================================================
  @PUT(ApiEndpoints.userProfile)
  Future<Map<String, dynamic>> updateUserProfile(
    @Part(name: 'name') String? name,
    @Part(name: 'phoneNumber') String? phoneNumber,
    @Part(name: 'email') String? email,
    @Part(name: 'dob') String? dob,
    // Backend now expects "male" / "female" / "other" (was numeric).
    @Part(name: 'gender') String? gender,
    @Part(name: 'UserProfileImage') File? userProfileImage,
    @Part(name: 'fcmToken') String? fcmToken,
  );

  // ============================================================
  // PROFILE — Update FCM token
  // PUT /api/v1/update-fcm  — JSON body { "fcmToken": "..." }
  // ============================================================
  @PUT(ApiEndpoints.updateFcm)
  Future<Map<String, dynamic>> updateFcmToken(
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // DASHBOARD — Get Home Dashboard Data
  // GET /api/v1/dashboard
  // ============================================================
  @GET(ApiEndpoints.dashboard)
  Future<Map<String, dynamic>> getDashboard();

  // ============================================================
  // COURSES — Get Courses By Tile
  // GET /api/v1/course/tile/{tileId}?isPaid=...
  //
  // DEPRECATED:
  // This endpoint has been replaced by the Course Catalog API.
  // Keep temporarily for backward compatibility and future reference.
  // ============================================================
  @GET(ApiEndpoints.coursesByTile)
  Future<Map<String, dynamic>> getCoursesByTile(
    @Path('tileId') int tileId,
    @Query('isPaid') bool? isPaid,
  );

  // ============================================================
  // COURSES — Get Courses By Category
  // GET /api/v1/course/category/{categoryId}?isPaid=...
  //
  // DEPRECATED:
  // This endpoint has been replaced by the Course Catalog API.
  // Keep temporarily for backward compatibility and future reference.
  // ============================================================
  @GET(ApiEndpoints.coursesByCategory)
  Future<Map<String, dynamic>> getCoursesByCategory(
    @Path('categoryId') int categoryId,
    @Query('isPaid') bool? isPaid,
  );

  // ============================================================
  // COURSES — Get Course Detail (v2)
  // GET /api/v1/course/{courseId}/v2
  //
  // v2 returns the pricing tier list under `data.pricing.pricing[]`
  // (each tier carries its own `coursePricingId` used by the v2
  // pricing-v2 + create-order-v2 endpoints).
  // ============================================================
  @GET(ApiEndpoints.courseDetail)
  Future<Map<String, dynamic>> getCourseDetail(@Path('courseId') int courseId);

  // ============================================================
  // COURSES — Get Trending Courses
  // GET /api/v1/course/trending-courses
  //
  // DEPRECATED:
  // This endpoint has been replaced by the Course Catalog API.
  // Keep temporarily for backward compatibility and future reference.
  // ============================================================
  @GET(ApiEndpoints.trendingCourses)
  Future<Map<String, dynamic>> getTrendingCourses();

  // ============================================================
  // COURSES — New Courses API (Not yet implemented)
  //
  // DEPRECATED:
  // This planned endpoint has been replaced by the Course Catalog API.
  // ============================================================

  // ============================================================
  // COURSES — Get Reviews by Course Id
  // GET /api/v1/course/{courseId}/reviews
  // ============================================================
  @GET(ApiEndpoints.courseReviews)
  Future<Map<String, dynamic>> getCourseReviews(@Path('courseId') int courseId);

  // ============================================================
  // COURSES — Save Course Review
  // POST /api/v1/course/review
  // Body: { courseId: int, rating: double, reviewMessage: String }
  // ============================================================
  @POST(ApiEndpoints.saveCourseReview)
  Future<Map<String, dynamic>> saveCourseReview(
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // COURSES — Save Continue Course (mark as enrolled / in-progress)
  // POST /api/v1/course/continue-course
  // Body: { courseId: int, isPurchased: bool }
  // ============================================================
  @POST(ApiEndpoints.continueCourse)
  Future<Map<String, dynamic>> saveContinueCourse(
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // COURSES — Get Continue Courses (user's enrolled / in-progress list)
  // GET /api/v1/course/continue-course
  // ============================================================
  @GET(ApiEndpoints.continueCourse)
  Future<Map<String, dynamic>> getContinueCourses();

  // ============================================================
  // CERTIFICATES — Completed courses (with per-course certificate flags)
  // GET /api/v1/certificate/completed
  //
  // The download companion is NOT declared here: it returns a PDF, so
  // it needs `ResponseType.bytes` and a longer receive timeout, which
  // it gets from raw Dio in CertificateRepositoryImpl.
  // ============================================================
  @GET(ApiEndpoints.certificateCompleted)
  Future<Map<String, dynamic>> getCompletedCertificateCourses();

  // ============================================================
  // WEBINARS — List (live + upcoming, org-scoped from the JWT)
  // GET /api/v1/webinars?pageNo=&pageSize=
  // ============================================================
  @GET(ApiEndpoints.webinars)
  Future<Map<String, dynamic>> getWebinars(
    @Query('pageNo') int pageNo,
    @Query('pageSize') int pageSize,
  );

  // ============================================================
  // WEBINARS — Detail
  // GET /api/v1/webinars/{slug}
  //
  // The account token is optional on the wire (the same endpoint serves
  // the public website anonymously), but the app always holds one, and
  // sending it is what scopes the lookup to the learner's own org and
  // fills in `isRegistered`.
  // ============================================================
  @GET(ApiEndpoints.webinarDetail)
  Future<Map<String, dynamic>> getWebinarDetail(@Path('slug') String slug);

  // ============================================================
  // WEBINARS — Join (take the seat)
  // POST /api/v1/webinars/{slug}/join
  //
  // No body: the learner is identified from the account token. In the
  // app they are already a registered user, so there is no form, no OTP
  // and no webview — that flow is the website's, for visitors with no
  // account. Idempotent, so retries need no special handling.
  // ============================================================
  @POST(ApiEndpoints.webinarJoinSeat)
  Future<Map<String, dynamic>> joinWebinar(@Path('slug') String slug);

  // ============================================================
  // WEBINARS — Lobby state (poll while canWatch is false)
  // GET /api/v1/webinars/{slug}/state
  // ============================================================
  @GET(ApiEndpoints.webinarState)
  Future<Map<String, dynamic>> getWebinarState(@Path('slug') String slug);

  // ============================================================
  // WEBINARS — Playback (signed HLS URL; also records attendance)
  // GET /api/v1/webinars/{slug}/playback
  // ============================================================
  @GET(ApiEndpoints.webinarPlayback)
  Future<Map<String, dynamic>> getWebinarPlayback(@Path('slug') String slug);

  // ============================================================
  // WEBINARS — Chat history (newest first)
  // GET /api/v1/webinars/{slug}/chat?beforeId=&limit=
  // ============================================================
  @GET(ApiEndpoints.webinarChat)
  Future<Map<String, dynamic>> getWebinarChat(
    @Path('slug') String slug,
    @Query('beforeId') int? beforeId,
    @Query('limit') int? limit,
  );

  // ============================================================
  // WEBINARS — StreamApi hub token for the chat socket
  // POST /api/v1/webinars/{slug}/hub-token
  // ============================================================
  @POST(ApiEndpoints.webinarHubToken)
  Future<Map<String, dynamic>> getWebinarHubToken(@Path('slug') String slug);

  // ============================================================
  // WEBINARS — P1, create a Razorpay order for a paid webinar
  // POST /api/v1/webinars/{slug}/create-order
  //
  // No body. The amount is read server-side from the database, so a
  // client cannot claim a price of its own.
  // ============================================================
  @POST(ApiEndpoints.webinarCreateOrder)
  Future<Map<String, dynamic>> createWebinarOrder(@Path('slug') String slug);

  // ============================================================
  // WEBINARS — P2, verify the payment and take the seat
  // POST /api/v1/webinars/{slug}/verify-payment
  //
  // The three ids come straight from Razorpay's success callback and go
  // out byte-for-byte — the signature is an HMAC, so trimming or
  // re-casing it is the same as corrupting it.
  // ============================================================
  @POST(ApiEndpoints.webinarVerifyPayment)
  Future<Map<String, dynamic>> verifyWebinarPayment(
    @Path('slug') String slug,
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // COURSES — Get My Courses (all purchased courses)
  // GET /api/v1/course/my-courses
  // ============================================================
  @GET(ApiEndpoints.myCourses)
  Future<Map<String, dynamic>> getMyCourses();

  // ============================================================
  // COURSES — Reset Rewatch (move a completed course back to
  // In Progress with progress 0).
  // PUT /api/v1/course/{purchasedId}/re-watch
  // ============================================================
  @PUT(ApiEndpoints.rewatchCourse)
  Future<Map<String, dynamic>> rewatchCourse(
    @Path('purchasedId') int purchasedId,
  );

  // ============================================================
  // COURSES — Record content node completion
  // POST /api/v1/course/completion
  // Body: { coursePurchasedId: int, jsonContentId: String }
  // ============================================================
  @POST(ApiEndpoints.courseCompletion)
  Future<Map<String, dynamic>> recordContentCompletion(
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // TRANSACTIONS — Payment history
  // GET /api/v1/course/transaction-history
  //   ?PaymentStatus=SUCCESS|FAILED|PENDING (optional)
  //   &Filter=LAST_WEEK|THIS_MONTH|LAST_MONTH (optional)
  // Both query params are dropped from the URL when null so the
  // backend serves the unfiltered list by default.
  // ============================================================
  @GET(ApiEndpoints.transactionHistory)
  Future<Map<String, dynamic>> getTransactionHistory(
    @Query('PaymentStatus') String? paymentStatus,
    @Query('Filter') String? filter,
  );

  // ============================================================
  // COURSES — Get Course Categories & Types (filter options)
  // GET /api/v1/course/categories
  // ============================================================
  @GET(ApiEndpoints.courseCategories)
  Future<Map<String, dynamic>> getCourseCategories();

  // ============================================================
  // COURSES — Search Courses
  // GET /api/v1/course/search?searchQuery=...&isPaid=...
  //
  // DEPRECATED:
  // This endpoint has been replaced by the Course Catalog API.
  // Keep temporarily for backward compatibility and future reference.
  // ============================================================
  @GET(ApiEndpoints.courseSearch)
  Future<Map<String, dynamic>> searchCourses(
    @Query('searchQuery') String searchQuery,
    @Query('isPaid') bool? isPaid,
  );

  // ============================================================
  // COURSES — Course Catalog
  // GET /api/v1/course/catalog
  // Supports optional query params: pageNo, searchQuery, courseType, categoryId, tileId, courseStatusType
  // ============================================================
  @GET(ApiEndpoints.courseCatalog)
  Future<Map<String, dynamic>> getCourseCatalog({
    @Query('pageNo') int? pageNo,
    @Query('searchQuery') String? searchQuery,
    @Query('courseType') String? courseType,
    @Query('categoryId') int? categoryId,
    @Query('tileId') int? tileId,
    @Query('courseStatusType') int? courseStatusType,
    @Query('sortBy') String? sortBy,
  });

  // ============================================================
  // COURSES — Get Course Pricing breakdown (v2)
  // GET /api/v1/course/pricing-v2?CourseId=&PriceId=
  //
  // Both ids are query params (PascalCase on the wire — Retrofit will
  // emit `?CourseId=20&PriceId=61` exactly as written). The PriceId
  // selects one of the tiers returned by the course-detail v2
  // `data.pricing.pricing[]` array; the response then ships the full
  // breakdown (tax, internet charges, platform fee, coupon-status
  // echo) for that specific tier. Coupon application is no longer a
  // query param on this endpoint — coupon-apply lives on a separate
  // route that the UI can wire up later.
  // ============================================================
  @GET(ApiEndpoints.coursePricing)
  Future<Map<String, dynamic>> getCoursePricing(
    @Query('CourseId') int courseId,
    @Query('PriceId') int priceId,
    @Query('couponCode') String? couponCode,
  );

  // ============================================================
  // COURSES — Get Course Assignment
  // GET /api/v1/course/{assignmentId}/assignment
  //
  // The path id is the assignment id (carried by the curriculum node's
  // `url` field), not the course id.
  // ============================================================
  @GET(ApiEndpoints.courseAssignment)
  Future<Map<String, dynamic>> getCourseAssignment(
    @Path('assignmentId') int assignmentId,
  );

  // ============================================================
  // COURSES — Submit Course Assignment (multipart)
  // POST /api/v1/course/assignment
  // Body fields: CourseId, AssignmentId, JsonNodeId, SubmissionId,
  // SubmissionFile (multipart binary).
  // ============================================================
  @POST(ApiEndpoints.submitCourseAssignment)
  Future<Map<String, dynamic>> submitCourseAssignment(
    @Part(name: 'CourseId') int courseId,
    @Part(name: 'AssignmentId') int assignmentId,
    @Part(name: 'JsonNodeId') String jsonNodeId,
    @Part(name: 'SubmissionId') int submissionId,
    @Part(name: 'SubmissionFile') File submissionFile,
  );

  // ============================================================
  // LIVE CLASSES — Resolve signed HLS playback URL
  // GET /api/stream/live-classes/{roomId}/playback
  // Auth: student JWT (default interceptor). Response envelope:
  // { success, message, data: { hlsUrl } }.
  // ============================================================
  @GET(ApiEndpoints.liveClassPlayback)
  Future<Map<String, dynamic>> getLiveClassPlayback(
    @Path('roomId') String roomId,
  );

  // ============================================================
  // LIVE CLASSES — Mint StreamApi token for the SignalR class hub
  // POST /api/stream/token → { success, message, data: { token } }
  // ============================================================
  @POST(ApiEndpoints.streamToken)
  Future<Map<String, dynamic>> getStreamToken();

  // ============================================================
  // LIVE CLASSES — Chat backfill / pagination
  // GET /api/stream/live-classes/{roomId}/chat?beforeId=&limit=
  // ============================================================
  @GET(ApiEndpoints.liveClassChat)
  Future<Map<String, dynamic>> getLiveClassChat(
    @Path('roomId') String roomId,
    @Query('beforeId') int? beforeId,
    @Query('limit') int? limit,
  );

  // ============================================================
  // EXAM — Gate (read-only; never creates an attempt)
  // GET /api/v1/exam/{examId}/gate?phoneNumber=
  // ============================================================
  @GET(ApiEndpoints.examGate)
  Future<Map<String, dynamic>> getExamGate(
    @Path('examId') int examId,
    @Query('phoneNumber') String phoneNumber,
  );

  // ============================================================
  // EXAM — Start (idempotent create-or-resume)
  // POST /api/v1/exam/{examId}/start   Body: { phoneNumber }
  // ============================================================
  @POST(ApiEndpoints.examStart)
  Future<Map<String, dynamic>> startExam(
    @Path('examId') int examId,
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // EXAM — Paper (normal mode; whole paper with saved answers)
  // GET /api/v1/exam/attempt/{attemptId}/paper?phoneNumber=
  // ============================================================
  @GET(ApiEndpoints.examPaper)
  Future<Map<String, dynamic>> getExamPaper(
    @Path('attemptId') int attemptId,
    @Query('phoneNumber') String phoneNumber,
  );

  // ============================================================
  // EXAM — Current question (competitive mode)
  // GET /api/v1/exam/attempt/{attemptId}/question?phoneNumber=
  // Stamps the server-side shown_at timer (idempotent).
  // ============================================================
  @GET(ApiEndpoints.examQuestion)
  Future<Map<String, dynamic>> getExamQuestion(
    @Path('attemptId') int attemptId,
    @Query('phoneNumber') String phoneNumber,
  );

  // ============================================================
  // EXAM — Answer current question (competitive mode)
  // POST /api/v1/exam/attempt/{attemptId}/answer
  // Body: { phoneNumber, answer: StudentAnswerRequest }
  // timeTakenSeconds is computed server-side from shown_at.
  // ============================================================
  @POST(ApiEndpoints.examAnswer)
  Future<Map<String, dynamic>> answerExamQuestion(
    @Path('attemptId') int attemptId,
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // EXAM — Autosave (normal mode; ungraded bulk save)
  // POST /api/v1/exam/attempt/{attemptId}/save
  // Body: { phoneNumber, answers: [StudentAnswerRequest] }
  // ============================================================
  @POST(ApiEndpoints.examSave)
  Future<Map<String, dynamic>> saveExamProgress(
    @Path('attemptId') int attemptId,
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // EXAM — Submit (final grading, both modes)
  // POST /api/v1/exam/attempt/{attemptId}/submit
  // Body: { phoneNumber, autoSubmitted, answers: [StudentAnswerRequest] }
  // ============================================================
  @POST(ApiEndpoints.examSubmit)
  Future<Map<String, dynamic>> submitExam(
    @Path('attemptId') int attemptId,
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // EXAM — Result (reopen one of the student's own attempts)
  // GET /api/v1/exam/attempt/{attemptId}/result?phoneNumber=
  // ============================================================
  @GET(ApiEndpoints.examResult)
  Future<Map<String, dynamic>> getExamResult(
    @Path('attemptId') int attemptId,
    @Query('phoneNumber') String phoneNumber,
  );

  // ============================================================
  // EXAM — History (all of the student's attempts, newest first)
  // GET /api/v1/exam/{examId}/history?phoneNumber=
  // ============================================================
  @GET(ApiEndpoints.examHistory)
  Future<Map<String, dynamic>> getExamHistory(
    @Path('examId') int examId,
    @Query('phoneNumber') String phoneNumber,
  );

  // ============================================================
  // EXAM — Reattempt (start a new attempt after a finished one)
  // POST /api/v1/exam/{examId}/reattempt   Body: { phoneNumber }
  // ============================================================
  @POST(ApiEndpoints.examReattempt)
  Future<Map<String, dynamic>> reattemptExam(
    @Path('examId') int examId,
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // NOTIFICATIONS — Get all notifications
  // GET /api/v1/notifications
  // ============================================================
  @GET(ApiEndpoints.notifications)
  Future<Map<String, dynamic>> getNotifications();

  // ============================================================
  // NOTIFICATIONS — Update read status
  // PUT /api/v1/notifications/{notificationId}/read-status
  // ============================================================
  @PUT(ApiEndpoints.notificationReadStatus)
  Future<Map<String, dynamic>> setNotificationReadStatus(
    @Path('notificationId') int notificationId,
  );

  // ============================================================
  // CHAT GROUPS — Get all chat groups for paid users
  // GET /api/v1/chat-group
  // ============================================================
  @GET(ApiEndpoints.chatGroups)
  Future<Map<String, dynamic>> getChatGroups();

  // ============================================================
  // CHAT — Generate dedicated chat token
  // GET /api/v1/generate-token-v2?name={name}
  //
  // Authorised by the main access token (the default auth
  // interceptor handles that). The returned token is the bearer
  // used for every other chat REST call AND for the SignalR hub.
  // Name is a query param; Dio URL-encodes it for us.
  // ============================================================
  @GET(ApiEndpoints.generateChatToken)
  Future<Map<String, dynamic>> generateChatToken(@Query('name') String name);

  // ============================================================
  // CHAT — Get message history for a group
  // GET /api/v1/chat-group/{groupId}/messages?page=&pageSize=
  //
  // Authorisation: chat token (explicit Authorization header), since
  // this endpoint is not behind the main app token.
  // ============================================================
  @GET(ApiEndpoints.chatMessages)
  Future<Map<String, dynamic>> getChatMessages(
    @Header('Authorization') String chatBearer,
    @Path('groupId') String groupId,
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );

  // ============================================================
  // CHAT — Delete a single message
  // DELETE /api/v1/chat-group/messages/{messageId}?groupId={groupId}
  //
  // Authorisation: chat token (explicit Authorization header).
  // ============================================================
  @DELETE(ApiEndpoints.deleteChatMessage)
  Future<Map<String, dynamic>> deleteChatMessage(
    @Header('Authorization') String chatBearer,
    @Path('messageId') int messageId,
    @Query('groupId') String groupId,
  );

  // ============================================================
  // DIRECT CHAT — the learner's 1-to-1 inbox
  // GET /api/v1/direct-chat/conversations
  //
  // Returns a BARE JSON ARRAY (not wrapped in `{data: …}`), so the
  // return type is List<dynamic> rather than the Map used everywhere
  // else in this client.
  //
  // Authorisation: chat token (explicit Authorization header).
  // ============================================================
  @GET(ApiEndpoints.directConversations)
  Future<List<dynamic>> getDirectConversations(
    @Header('Authorization') String chatBearer,
  );

  // ============================================================
  // DIRECT CHAT — open (or reuse) a thread with a staff member
  // POST /api/v1/direct-chat/conversations   body: {targetUserId}
  //
  // Idempotent: calling it twice returns the same thread, so it's safe
  // to fire on every screen entry. `404` means the target isn't a
  // member of this org — do not retry.
  // ============================================================
  @POST(ApiEndpoints.directConversations)
  Future<Map<String, dynamic>> startDirectConversation(
    @Header('Authorization') String chatBearer,
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // DIRECT CHAT — staff the learner may message
  // GET /api/v1/direct-chat/directory
  //
  // Bare JSON array. Each entry carries a precomputed
  // `conversationKey` so the caller can check the inbox before
  // POSTing a new thread.
  // ============================================================
  @GET(ApiEndpoints.directDirectory)
  Future<List<dynamic>> getDirectDirectory(
    @Header('Authorization') String chatBearer,
  );

  // ============================================================
  // DIRECT CHAT — message history for one thread
  // GET /api/v1/direct-chat/conversations/{conversationKey}/messages
  //     ?page=&pageSize=
  //
  // Identical payload shape to getChatMessages — PagedChatMessages
  // parses it unchanged. `conversationKey` must arrive URL-encoded.
  // ============================================================
  @GET(ApiEndpoints.directMessages)
  Future<Map<String, dynamic>> getDirectMessages(
    @Header('Authorization') String chatBearer,
    @Path('conversationKey') String conversationKey,
    @Query('page') int page,
    @Query('pageSize') int pageSize,
  );

  // ============================================================
  // DIRECT CHAT — unread badge for one thread
  // GET /api/v1/direct-chat/conversations/{conversationKey}/unread-count
  // ============================================================
  @GET(ApiEndpoints.directUnreadCount)
  Future<Map<String, dynamic>> getDirectUnreadCount(
    @Header('Authorization') String chatBearer,
    @Path('conversationKey') String conversationKey,
  );

  // ============================================================
  // DIRECT CHAT — clear a thread's badge over REST
  // POST /api/v1/direct-chat/conversations/{key}/read?lastReadMessageId=
  //
  // Responds `204 No Content`, hence the void return.
  // ============================================================
  @POST(ApiEndpoints.directMarkRead)
  Future<void> markDirectConversationRead(
    @Header('Authorization') String chatBearer,
    @Path('conversationKey') String conversationKey,
    @Query('lastReadMessageId') int lastReadMessageId,
  );

  // ============================================================
  // DIRECT CHAT — delete one of the learner's own messages
  // DELETE /api/v1/direct-chat/messages/{messageId}?conversationKey=
  //
  // Responds `204 No Content`, hence the void return.
  // ============================================================
  @DELETE(ApiEndpoints.directDeleteMessage)
  Future<void> deleteDirectMessage(
    @Header('Authorization') String chatBearer,
    @Path('messageId') int messageId,
    @Query('conversationKey') String conversationKey,
  );

  // ============================================================
  // DIRECT CHAT — edit one of the learner's own text messages
  // PUT /api/v1/direct-chat/messages/{messageId}
  //   body: { conversationKey, message }
  //
  // Author-only, text-only, non-empty, and within 2 minutes of
  // sending — the server enforces all four (403 / 400). Returns the
  // full updated message, so ChatMessage.fromJson parses the response
  // directly.
  // ============================================================
  @PUT(ApiEndpoints.directEditMessage)
  Future<Map<String, dynamic>> editDirectMessage(
    @Header('Authorization') String chatBearer,
    @Path('messageId') int messageId,
    @Body() Map<String, dynamic> body,
  );

  // ============================================================
  // DIRECT CHAT — clear the thread for this caller only
  // POST /api/v1/direct-chat/conversations/{key}/clear
  //
  // A per-reader watermark, NOT a delete: the other party keeps the
  // full history. Returns { conversationKey, clearedUpToMessageId }.
  // ============================================================
  @POST(ApiEndpoints.directClearConversation)
  Future<Map<String, dynamic>> clearDirectConversation(
    @Header('Authorization') String chatBearer,
    @Path('conversationKey') String conversationKey,
  );

  // ============================================================
  // ORGANIZATION — Get org info (WhatsApp / T&C / Refund Policy)
  // GET /api/v1/organization-info
  //   ?whatsappNumber=true|false
  //   &termsAndCondition=true|false
  //   &refundPolicy=true|false
  //
  // Exactly one param should be `true` per call; the others should be
  // `false`.  The server returns only the requested data in `data`.
  // ============================================================
  @GET(ApiEndpoints.organizationInfo)
  Future<Map<String, dynamic>> getOrganizationInfo({
    @Query('whatsappNumber') bool? whatsappNumber,
    @Query('termsAndCondition') bool? termsAndCondition,
    @Query('refundPolicy') bool? refundPolicy,
  });

  // ============================================================
  // App rating URL (Play Store / App Store)
  // GET /api/v1/app-rating-url?deviceType=android|ios
  //
  // Org is resolved from the JWT. `data.ratingUrl` is null when the
  // org hasn't configured a rating URL for that platform.
  // ============================================================
  @GET(ApiEndpoints.appRatingUrl)
  Future<Map<String, dynamic>> getAppRatingUrl({
    @Query('deviceType') required String deviceType,
  });

  // ============================================================
  // WORKSHOP PASS — the attendee's entry ticket
  // GET /api/v1/workshop-pass/{slug}
  //
  // `slug` is the webinar's `publicSlug`, not the numeric id. The
  // attendee and the org both come from the JWT, so nothing here
  // identifies a user.
  //
  // `data.html` is a whole HTML document (doctype, inlined CSS, the
  // lot) — the same Razor partial the admin panel previews and the PDF
  // prints. Hand it to a WebView; never rebuild the ticket natively or
  // it drifts the first time an organiser restyles a design.
  //
  // Refusals are branched on status, not on the message: 402 is "not
  // bought yet" (route to checkout, it is not an error), 409 is the
  // organiser's problem, 404 is no such workshop for this org.
  // ============================================================
  @GET(ApiEndpoints.workshopPass)
  Future<Map<String, dynamic>> getWorkshopPass(@Path('slug') String slug);

  // ============================================================
  // WORKSHOP PASS — everything this learner booked
  // GET /api/v1/workshop-pass/my?pageNo=&pageSize=
  //
  // Both routes in are returned: tickets bought and free
  // registrations, de-duplicated to one row per webinar. Every
  // platform, not only workshops, and cancelled/finished events too —
  // it is a history, not a schedule.
  //
  // No business refusals: an empty history is a 200 with `total: 0`.
  // ============================================================
  @GET(ApiEndpoints.myWebinars)
  Future<Map<String, dynamic>> getMyWebinars(
    @Query('pageNo') int pageNo,
    @Query('pageSize') int pageSize,
  );

  // ============================================================
  // PAYMENTS — Create Razorpay Order (v2)
  // POST /api/v1/payments/create-order-v2
  // Body: { courseId: int, priceId: int }
  //
  // v2 derives the chargeable amount on the server from the
  // (courseId, priceId) pair instead of taking it from the client,
  // so the client can't drift from the backend-calculated total.
  // Response shape (Razorpay order) is unchanged from v1.
  // ============================================================
  @POST(ApiEndpoints.createOrder)
  Future<Map<String, dynamic>> createOrder(@Body() Map<String, dynamic> body);

  // ============================================================
  // PAYMENTS — Verify Payment
  // POST /api/payments/verify-payment
  // Body: { razorpayOrderId, razorpayPaymentId, razorpaySignature }
  // ============================================================
  @POST(ApiEndpoints.verifyPayment)
  Future<Map<String, dynamic>> verifyPayment(@Body() Map<String, dynamic> body);
}
