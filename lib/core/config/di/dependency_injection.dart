import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:nexora/core/storage/secure_storage.dart';
import 'package:nexora/core/network/api_client.dart';
import 'package:nexora/core/theme/bloc/theme_cubit.dart';
import 'package:nexora/core/session/session_service.dart';
import 'package:nexora/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:nexora/features/payment/domain/repositories/payment_repository.dart';
import 'package:nexora/features/payment/domain/usecases/create_order_usecase.dart';
import 'package:nexora/features/payment/domain/usecases/verify_payment_usecase.dart';
import 'package:nexora/features/payment/presentation/bloc/payment_cubit.dart';
import 'package:nexora/core/network/dio_client.dart';
import 'package:nexora/core/network/token_refresh_service.dart';
import 'package:nexora/features/home/data/repositories/home_repository_impl.dart';
import 'package:nexora/features/home/domain/repositories/home_repository.dart';
import 'package:nexora/features/home/domain/usecases/get_home_data_usecase.dart';
import 'package:nexora/features/home/presentation/bloc/home_cubit.dart';
import 'package:nexora/features/courses/data/repositories/course_repository_impl.dart';
import 'package:nexora/features/courses/domain/repositories/course_repository.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_detail_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_reviews_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_courses_by_category_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_courses_by_tile_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_continue_courses_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_my_courses_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/rewatch_course_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/record_content_completion_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_live_class_playback_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_stream_token_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_live_class_chat_usecase.dart';
import 'package:nexora/features/courses/data/services/live_class_audio_service.dart';
import 'package:nexora/core/services/content_completion_service.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_pricing_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_categories_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_trending_courses_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/save_continue_course_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/save_course_review_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/search_courses_usecase.dart';
import 'package:nexora/features/courses/domain/usecases/get_course_catalog_usecase.dart';
import 'package:nexora/features/courses/presentation/bloc/continue_courses_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/my_courses_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/course_pricing_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/pricing_tiers_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/course_detail_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/course_list_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/course_reviews_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/course_filters_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/live_class_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/live_now_cubit.dart';
import 'package:nexora/features/courses/presentation/bloc/search_courses_cubit.dart';
import 'package:nexora/features/chats/data/repositories/chat_group_repository_impl.dart';
import 'package:nexora/features/chats/data/services/chat_token_provider.dart';
import 'package:nexora/features/chats/data/services/signalr_chat_service.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';
import 'package:nexora/features/chats/domain/usecases/get_chat_groups_usecase.dart';
import 'package:nexora/features/chats/presentation/bloc/chat_groups_cubit.dart';
import 'package:nexora/features/direct_chat/data/repositories/direct_chat_repository_impl.dart';
import 'package:nexora/features/direct_chat/domain/repositories/direct_chat_repository.dart';
import 'package:nexora/features/direct_chat/presentation/bloc/direct_inbox_cubit.dart';
import 'package:nexora/features/auth/data/repositories/org_code_repository_impl.dart';
import 'package:nexora/features/auth/data/repositories/otp_repository_impl.dart';
import 'package:nexora/features/auth/domain/repositories/org_code_repository.dart';
import 'package:nexora/features/auth/domain/repositories/otp_repository.dart';
import 'package:nexora/features/auth/domain/usecases/resend_otp_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/resend_otp_v2_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/send_otp_v2_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/validate_org_code_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:nexora/features/auth/domain/usecases/verify_otp_v2_usecase.dart';
import 'package:nexora/features/auth/presentation/bloc/org_code_cubit.dart';
import 'package:nexora/features/auth/presentation/bloc/otp_cubit.dart';
import 'package:nexora/features/assignment/data/repositories/assignment_repository_impl.dart';
import 'package:nexora/features/assignment/domain/repositories/assignment_repository.dart';
import 'package:nexora/features/assignment/domain/usecases/get_assignment_usecase.dart';
import 'package:nexora/features/assignment/domain/usecases/submit_assignment_usecase.dart';
import 'package:nexora/features/assignment/presentation/bloc/assignment_cubit.dart';
import 'package:nexora/features/exam/data/repositories/exam_repository_impl.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';
import 'package:nexora/features/exam/domain/usecases/answer_exam_question_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_gate_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_question_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_history_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_paper_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_result_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/reattempt_exam_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/save_exam_progress_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/start_exam_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/submit_exam_usecase.dart';
import 'package:nexora/features/exam/presentation/bloc/exam_cubit.dart';
import 'package:nexora/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:nexora/features/notification/domain/repositories/notification_repository.dart';
import 'package:nexora/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:nexora/features/notification/domain/usecases/mark_notification_read_usecase.dart';
import 'package:nexora/features/notification/presentation/bloc/notification_cubit.dart';
import 'package:nexora/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:nexora/features/profile/domain/repositories/profile_repository.dart';
import 'package:nexora/features/profile/domain/usecases/get_app_rating_url_usecase.dart';
import 'package:nexora/features/profile/domain/usecases/get_org_info_usecase.dart';
import 'package:nexora/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:nexora/features/profile/domain/usecases/update_fcm_token_usecase.dart';
import 'package:nexora/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:nexora/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:nexora/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:nexora/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:nexora/features/transaction/domain/usecases/get_transaction_history_usecase.dart';
import 'package:nexora/features/transaction/domain/usecases/download_receipt_usecase.dart';
import 'package:nexora/features/certificate/data/repositories/certificate_repository_impl.dart';
import 'package:nexora/features/certificate/domain/repositories/certificate_repository.dart';
import 'package:nexora/features/certificate/domain/usecases/download_certificate_usecase.dart';
import 'package:nexora/features/certificate/domain/usecases/get_completed_courses_usecase.dart';
import 'package:nexora/features/certificate/presentation/bloc/certificate_cubit.dart';
import 'package:nexora/features/webinar/data/repositories/webinar_repository_impl.dart';
import 'package:nexora/features/webinar/domain/repositories/webinar_repository.dart';
import 'package:nexora/features/webinar/domain/usecases/get_webinar_detail_usecase.dart';
import 'package:nexora/features/webinar/domain/usecases/get_webinars_usecase.dart';
import 'package:nexora/features/webinar/domain/usecases/webinar_payment_usecases.dart';
import 'package:nexora/features/webinar/domain/usecases/webinar_session_usecases.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_checkout_cubit.dart';
import 'package:nexora/features/workshop_pass/data/repositories/workshop_pass_repository_impl.dart';
import 'package:nexora/features/workshop_pass/data/services/workshop_pass_cache.dart';
import 'package:nexora/features/workshop_pass/domain/repositories/workshop_pass_repository.dart';
import 'package:nexora/features/workshop_pass/domain/usecases/download_workshop_pass_usecase.dart';
import 'package:nexora/features/workshop_pass/domain/usecases/get_workshop_pass_usecase.dart';
import 'package:nexora/features/workshop_pass/presentation/bloc/workshop_pass_cubit.dart';
import 'package:nexora/features/workshop_pass/domain/usecases/get_my_webinars_usecase.dart';
import 'package:nexora/features/workshop_pass/presentation/bloc/my_webinars_cubit.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_detail_cubit.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_room_cubit.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinars_cubit.dart';
import 'package:nexora/features/transaction/presentation/bloc/transaction_history_cubit.dart';

/// Global service locator instance
final sl = GetIt.instance;

/// Setup dependency injection
/// Call this in main.dart before runApp
Future<void> setupLocator() async {
  // ============================================
  // CORE
  // ============================================
  // Network
  sl.registerLazySingleton<Dio>(() => createDioClient());
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl<Dio>()));

  // Silent session renewal. Runs on its own bare Dio — see the class doc:
  // routing it through sl<Dio>() would put the refresh call behind the
  // very interceptor that asks for the refresh. Lazy, so the first
  // resolution happens on the first 401 rather than at startup.
  sl.registerLazySingleton<TokenRefreshService>(
    () => TokenRefreshService(sl<SessionService>()),
  );

  // Appearance — singleton so the profile toggle and MaterialApp read
  // and write the same instance. `main.dart` awaits `load()` before
  // runApp so the first frame paints in the persisted theme.
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit(secureStorage));

  // ============================================
  // FEATURES - HOME
  // ============================================
  // Repository
  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(sl<ApiClient>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetHomeDataUseCase(sl()));

  // Cubit
  sl.registerFactory(() => HomeCubit(sl()));

  // ============================================
  // FEATURES - COURSES
  // ============================================
  // Repository
  sl.registerLazySingleton<CourseRepository>(
    () => CourseRepositoryImpl(sl<ApiClient>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetCoursesByTileUseCase(sl()));
  sl.registerLazySingleton(() => GetCoursesByCategoryUseCase(sl()));
  sl.registerLazySingleton(() => GetCourseDetailUseCase(sl()));
  sl.registerLazySingleton(() => GetTrendingCoursesUseCase(sl()));
  sl.registerLazySingleton(() => GetCourseReviewsUseCase(sl()));
  sl.registerLazySingleton(() => SaveCourseReviewUseCase(sl()));
  sl.registerLazySingleton(() => SaveContinueCourseUseCase(sl()));
  sl.registerLazySingleton(() => GetContinueCoursesUseCase(sl()));
  sl.registerLazySingleton(() => GetMyCoursesUseCase(sl()));
  sl.registerLazySingleton(() => RewatchCourseUseCase(sl()));
  sl.registerLazySingleton(() => RecordContentCompletionUseCase(sl()));
  // Singleton — owns a session-level dedup cache so back-to-back triggers
  // (replay, seek-back, hot-reload) on the same node don't re-POST.
  sl.registerLazySingleton(() => ContentCompletionService(sl()));
  sl.registerLazySingleton(() => GetLiveClassPlaybackUseCase(sl()));
  sl.registerLazySingleton(() => GetStreamTokenUseCase(sl()));
  sl.registerLazySingleton(() => GetLiveClassChatUseCase(sl()));
  // Audio-only LiveKit wrapper — one live turn per instance, so a
  // factory (fresh per cubit / per speak session).
  sl.registerFactory(() => LiveClassAudioService());
  sl.registerLazySingleton(() => SearchCoursesUseCase(sl()));
  sl.registerLazySingleton(() => GetCourseCatalogUseCase(sl()));
  sl.registerLazySingleton(() => GetCoursePricingUseCase(sl()));
  sl.registerLazySingleton(() => GetCourseCategoriesUseCase(sl()));

  // Cubits
  sl.registerFactory(
    () => CourseListCubit(
      getCoursesByTileUseCase: sl(),
      getCoursesByCategoryUseCase: sl(),
      getCourseCatalogUseCase: sl(),
    ),
  );
  sl.registerFactory(
    () => CourseDetailCubit(
      getCourseDetailUseCase: sl(),
      saveContinueCourseUseCase: sl(),
    ),
  );
  sl.registerFactory(
    () => CourseReviewsCubit(
      getCourseReviewsUseCase: sl(),
      saveCourseReviewUseCase: sl(),
    ),
  );
  sl.registerFactory(
    () => ContinueCoursesCubit(getContinueCoursesUseCase: sl()),
  );
  sl.registerFactory(
    () => LiveNowCubit(
      getMyCoursesUseCase: sl(),
      getCourseDetailUseCase: sl(),
    ),
  );
  sl.registerFactory(
    () => MyCoursesCubit(getMyCoursesUseCase: sl(), rewatchCourseUseCase: sl()),
  );
  sl.registerFactory(() => SearchCoursesCubit(getCourseCatalogUseCase: sl()));
  sl.registerFactory(() => CoursePricingCubit(getCoursePricingUseCase: sl()));
  sl.registerFactory(
    () => LiveClassCubit(
      getLiveClassPlaybackUseCase: sl(),
      getStreamTokenUseCase: sl(),
      getLiveClassChatUseCase: sl(),
      audioService: sl(),
      sessionService: sl<SessionService>(),
    ),
  );
  sl.registerFactory(() => PricingTiersCubit(getCourseDetailUseCase: sl()));
  sl.registerFactory(
    () => CourseFiltersCubit(getCourseCategoriesUseCase: sl()),
  );

  // ============================================
  // FEATURES - CHATS
  // ============================================
  // One owner of the chat JWT for both group and personal chat — they
  // share a token, so a second mint path would just be a second thing
  // to keep in sync.
  sl.registerLazySingleton<ChatTokenProvider>(
    () => ChatTokenProvider(sl<ApiClient>(), sl<SessionService>()),
  );
  sl.registerLazySingleton<ChatGroupRepository>(
    () => ChatGroupRepositoryImpl(sl<ApiClient>(), sl<ChatTokenProvider>()),
  );
  sl.registerLazySingleton(() => GetChatGroupsUseCase(sl()));
  // SignalRChatService is a singleton so the WebSocket lives for the
  // whole session — joining a new room is then just an invoke()
  // instead of a fresh TCP / TLS handshake. Per-screen state (the
  // active groupId, broadcast streams) is owned by the service; the
  // page-level ChatRoomCubit only subscribes / unsubscribes.
  sl.registerLazySingleton<SignalRChatService>(
    () => SignalRChatService(sl<SessionService>()),
  );
  sl.registerFactory(() => ChatGroupsCubit(getChatGroupsUseCase: sl()));
  // ChatRoomCubit is constructed inline by ChatRoomPage's BlocProvider
  // (one per screen, with the room's groupId baked in) so we don't
  // register it here — DI just needs the repo + SignalR service that
  // the cubit pulls from `sl`.

  // ============================================
  // FEATURES - DIRECT CHAT (1-to-1 student ↔ staff)
  // ============================================
  sl.registerLazySingleton<DirectChatRepository>(
    () => DirectChatRepositoryImpl(sl<ApiClient>(), sl<ChatTokenProvider>()),
  );
  // Lazy SINGLETON, unlike ChatGroupsCubit's factory: this cubit stays
  // subscribed to the hub's `DirectInboxUpdated` event, which is
  // addressed to the user by id rather than a joined group and so
  // arrives even when the inbox screen isn't mounted. A per-screen
  // instance would drop those and let unread counts go stale.
  //
  // Screens must provide it with `BlocProvider.value` — a plain
  // BlocProvider closes its bloc on dispose.
  sl.registerLazySingleton<DirectInboxCubit>(
    () => DirectInboxCubit(
      repository: sl<DirectChatRepository>(),
      chatGroupRepository: sl<ChatGroupRepository>(),
      signalr: sl<SignalRChatService>(),
    ),
  );
  // DirectChatRoomCubit is constructed inline by DirectChatRoomPage's
  // BlocProvider (one per screen, with the conversationKey baked in),
  // mirroring ChatRoomCubit.

  // ============================================
  // FEATURES - OTP / ORG CODE
  // ============================================
  // Repository
  sl.registerLazySingleton<OtpRepository>(
    () => OtpRepositoryImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<OrgCodeRepository>(
    () => OrgCodeRepositoryImpl(sl<ApiClient>()),
  );

  // Use Cases — v1
  sl.registerLazySingleton(() => SendOtpUseCase(sl()));
  sl.registerLazySingleton(() => VerifyOtpUseCase(sl()));
  sl.registerLazySingleton(() => ResendOtpUseCase(sl()));
  // Use Cases — v2 (phone OR email recipient)
  sl.registerLazySingleton(() => SendOtpV2UseCase(sl()));
  sl.registerLazySingleton(() => VerifyOtpV2UseCase(sl()));
  sl.registerLazySingleton(() => ResendOtpV2UseCase(sl()));
  // Use Case — org code validation
  sl.registerLazySingleton(() => ValidateOrgCodeUseCase(sl()));

  // Cubit — carries both v1 + v2 dispatchers.
  sl.registerFactory(
    () => OtpCubit(
      verifyOtpUseCase: sl(),
      resendOtpUseCase: sl(),
      verifyOtpV2UseCase: sl(),
      resendOtpV2UseCase: sl(),
    ),
  );

  // Cubit — org code validation (one per page visit).
  sl.registerFactory(() => OrgCodeCubit(sl()));

  // ============================================
  // FEATURES - ASSIGNMENT
  // ============================================
  sl.registerLazySingleton<AssignmentRepository>(
    () => AssignmentRepositoryImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton(() => GetAssignmentUseCase(sl()));
  sl.registerLazySingleton(() => SubmitAssignmentUseCase(sl()));
  sl.registerFactory(
    () => AssignmentCubit(
      getAssignmentUseCase: sl(),
      submitAssignmentUseCase: sl(),
    ),
  );

  // ============================================
  // FEATURES - EXAM
  // ============================================
  sl.registerLazySingleton<ExamRepository>(
    () => ExamRepositoryImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton(() => GetExamGateUseCase(sl()));
  sl.registerLazySingleton(() => StartExamUseCase(sl()));
  sl.registerLazySingleton(() => GetExamPaperUseCase(sl()));
  sl.registerLazySingleton(() => GetExamQuestionUseCase(sl()));
  sl.registerLazySingleton(() => AnswerExamQuestionUseCase(sl()));
  sl.registerLazySingleton(() => SaveExamProgressUseCase(sl()));
  sl.registerLazySingleton(() => SubmitExamUseCase(sl()));
  sl.registerLazySingleton(() => GetExamResultUseCase(sl()));
  sl.registerLazySingleton(() => GetExamHistoryUseCase(sl()));
  sl.registerLazySingleton(() => ReattemptExamUseCase(sl()));
  sl.registerFactory(
    () => ExamCubit(
      repository: sl(),
      getGate: sl(),
      startExam: sl(),
      getPaper: sl(),
      getQuestion: sl(),
      answerQuestion: sl(),
      saveProgress: sl(),
      submitExam: sl(),
      getResult: sl(),
      getHistory: sl(),
      reattemptExam: sl(),
    ),
  );

  // ============================================
  // FEATURES - NOTIFICATION
  // ============================================
  // Repository
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(sl<ApiClient>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetNotificationsUseCase(sl()));
  sl.registerLazySingleton(() => MarkNotificationReadUseCase(sl()));

  // Cubit
  sl.registerFactory(
    () => NotificationCubit(getNotifications: sl(), markNotificationRead: sl()),
  );

  // ============================================
  // FEATURES - PROFILE
  // ============================================
  // Repository
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl<ApiClient>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetProfileUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton(() => UpdateFcmTokenUseCase(sl()));
  sl.registerLazySingleton(() => GetOrgInfoUseCase(sl()));
  sl.registerLazySingleton(() => GetAppRatingUrlUseCase(sl()));

  // Cubit — singleton because the same profile state needs to be observed
  // by Home (avatar + name in the header), Profile page, and Edit Profile
  // (which writes through it). Factory semantics would give each consumer
  // its own copy and updates wouldn't propagate.
  sl.registerLazySingleton(
    () => ProfileCubit(
      getProfileUseCase: sl(),
      updateProfileUseCase: sl(),
      updateFcmTokenUseCase: sl(),
    ),
  );

  // ============================================================
  // PAYMENT
  // ============================================================
  sl.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => CreateOrderUseCase(sl()));
  sl.registerLazySingleton(() => VerifyPaymentUseCase(sl()));
  sl.registerFactory(
    () => PaymentCubit(createOrderUseCase: sl(), verifyPaymentUseCase: sl()),
  );

  // ============================================
  // FEATURES - TRANSACTIONS
  // ============================================
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(sl<ApiClient>(), sl<Dio>()),
  );
  sl.registerLazySingleton(() => GetTransactionHistoryUseCase(sl()));
  sl.registerFactory(
    () => TransactionHistoryCubit(getTransactionHistoryUseCase: sl()),
  );
  sl.registerLazySingleton(() => DownloadReceiptUseCase(sl()));

  // ============================================
  // FEATURES - CERTIFICATES
  // ============================================
  // Takes raw Dio alongside ApiClient: the download returns a PDF, so it
  // needs ResponseType.bytes + a longer receive timeout than the
  // generated client can express.
  sl.registerLazySingleton<CertificateRepository>(
    () => CertificateRepositoryImpl(sl<ApiClient>(), sl<Dio>()),
  );
  sl.registerLazySingleton(() => GetCompletedCoursesUseCase(sl()));
  sl.registerLazySingleton(() => DownloadCertificateUseCase(sl()));
  sl.registerFactory(
    () => CertificateCubit(getCompletedCoursesUseCase: sl()),
  );

  // ============================================
  // FEATURES - WEBINARS
  // ============================================
  sl.registerLazySingleton<WebinarRepository>(
    () => WebinarRepositoryImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton(() => GetWebinarsUseCase(sl()));
  sl.registerLazySingleton(() => GetWebinarDetailUseCase(sl()));
  // Factories, not singletons: the Dashboard owns one WebinarsCubit for
  // the Home rail while the "View All" page pages through its own.
  sl.registerFactory(() => WebinarsCubit(getWebinarsUseCase: sl()));
  sl.registerFactory(
    () => WebinarDetailCubit(getWebinarDetailUseCase: sl()),
  );
  // A3–A7 — the room. Joining is a plain authenticated call here: in the
  // app the learner already has an account, so there is no registration
  // step and no webinar-scoped token to manage.
  sl.registerLazySingleton(() => JoinWebinarUseCase(sl()));
  sl.registerLazySingleton(() => GetWebinarStateUseCase(sl()));
  sl.registerLazySingleton(() => GetWebinarPlaybackUseCase(sl()));
  sl.registerLazySingleton(() => GetWebinarChatUseCase(sl()));
  sl.registerLazySingleton(() => GetWebinarHubTokenUseCase(sl()));
  sl.registerFactory(
    () => WebinarRoomCubit(
      joinWebinarUseCase: sl(),
      getWebinarStateUseCase: sl(),
      getWebinarPlaybackUseCase: sl(),
      getWebinarChatUseCase: sl(),
      getWebinarHubTokenUseCase: sl(),
      sessionService: sl(),
      // Factory-scoped: one LiveKit wrapper per room, torn down with the
      // cubit so a speaking turn can't outlive the screen that started
      // it.
      audioService: sl(),
    ),
  );
  // P1/P2 — paid webinars. Separate from the room cubit on purpose: a
  // free webinar never touches these, and the checkout runs on the
  // detail screen, before there is a room to be in.
  sl.registerLazySingleton(() => CreateWebinarOrderUseCase(sl()));
  sl.registerLazySingleton(() => VerifyWebinarPaymentUseCase(sl()));
  sl.registerFactory(
    () => WebinarCheckoutCubit(
      createWebinarOrderUseCase: sl(),
      verifyWebinarPaymentUseCase: sl(),
    ),
  );

  // ============================================
  // FEATURES - WORKSHOP PASS
  // ============================================
  // The entry ticket for a paid in-person workshop. Takes raw Dio
  // alongside ApiClient for the same reason the certificate repository
  // does — the save action returns a PDF, which needs
  // ResponseType.bytes and a far longer receive timeout than the
  // generated client can express.
  sl.registerLazySingleton(() => WorkshopPassCache());
  sl.registerLazySingleton<WorkshopPassRepository>(
    () => WorkshopPassRepositoryImpl(
      sl<ApiClient>(),
      sl<Dio>(),
      sl<WorkshopPassCache>(),
    ),
  );
  sl.registerLazySingleton(() => GetWorkshopPassUseCase(sl()));
  sl.registerLazySingleton(() => DownloadWorkshopPassUseCase(sl()));
  // Factory: one cubit per open pass screen, so two workshops opened
  // back to back never share a ticket.
  sl.registerFactory(
    () => WorkshopPassCubit(getWorkshopPassUseCase: sl()),
  );
  // My Bookings. Shares the pass repository because it is the same API
  // family: this list is what makes a pass reachable once the app is no
  // longer holding the slug from the purchase that issued it.
  sl.registerLazySingleton(() => GetMyWebinarsUseCase(sl()));
  sl.registerFactory(
    () => MyWebinarsCubit(getMyWebinarsUseCase: sl()),
  );

  // ============================================
  // EXTERNAL
  // ============================================
}
