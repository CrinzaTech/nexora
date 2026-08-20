import 'branding_config.dart';

/// App image / asset path constants.
///
/// Brand-driven paths (logo, logo-with-text, login + splash
/// backgrounds) come from [currentBranding] so onboarding a new
/// client is a single-line flip in `branding_config.dart`. Everything
/// else (avatars, navbar icons, generic glyphs) stays as direct
/// `static const` strings since those assets aren't brand-specific.
///
/// Same `static final` rationale as `AppColors`: Dart can't const-
/// evaluate field access on a const object, so brand tokens drop the
/// `const` modifier and are lazy-init instead. Runtime cost is one
/// resolve per token.
class AppImages {
  AppImages._();

  // ============================================
  // LOGOS — brand-driven via BrandingConfig
  // ============================================
  static final String logo = currentBranding.logo;
  static final String logoWithText = currentBranding.logoWithText;

  // ============================================
  // BACKGROUNDS — brand-driven via BrandingConfig
  // ============================================
  static final String loginBackground = currentBranding.loginBackground;
  static final String splashBackground = currentBranding.splashBackground;
  // static const String accountSetupBackground =
  //     'assets/images/backgrounds/account_setup_background.png';

  // ============================================
  // ONBOARDING
  // ============================================
  // static const String onboarding1 = 'assets/images/onboarding_1.png';
  // static const String onboarding2 = 'assets/images/onboarding_2.png';
  // static const String onboarding3 = 'assets/images/onboarding_3.png';

  // ============================================
  // ILLUSTRATIONS
  // ============================================
  // static const String emptyState = 'assets/images/empty_state.png';
  // static const String errorState = 'assets/images/error_state.png';
  // static const String successState = 'assets/images/success_state.png';

  // ============================================
  // SOCIAL ICONS
  // ============================================
  // static const String googleLogo = 'assets/icons/google.png';
  // static const String facebookLogo = 'assets/icons/facebook.png';
  // static const String appleLogo = 'assets/icons/apple.png';

  // ============================================
  // PLACEHOLDERS
  // ============================================
  // static const String placeholder = 'assets/images/placeholder.png';
  static const String avatarPlaceholder =
      'assets/images/person/avatar_placeholder.jpg';
  static const String bookImg = "assets/icons/bookImg.png";

  // ============================================
  // Icons
  // ============================================

  // Bottom Navbar Icons
  static const String homeSelectedIcon =
      'assets/icons/navbar/home_selected.png';
  static const String homeUnselectedIcon =
      'assets/icons/navbar/home_unselected.png';
  static const String chatSelectedIcon =
      'assets/icons/navbar/chat_selected.png';
  static const String chatUnselectedIcon =
      'assets/icons/navbar/chat_unselected.png';
  static const String courseSelectedIcon =
      'assets/icons/navbar/course_selected.png';
  static const String courseUnselectedIcon =
      'assets/icons/navbar/course_unselected.png';
  static const String profileSelectedIcon =
      'assets/icons/navbar/person_selected.png';
  static const String profileUnselectedIcon =
      'assets/icons/navbar/person_unselected.png';

  static const String arrowRightIcon = 'assets/icons/arrow_right.png';
  static const String arrowLeftIcon = 'assets/icons/arrow_left.png';
  static const String searchIcon = 'assets/icons/search.png';
  static const String personIcon = 'assets/icons/person.png';
  static const String callIcon = 'assets/icons/call.png';
  static const String documentIcon = 'assets/icons/document.png';
  static const String exitIcon = 'assets/icons/exit.png';
  static const String helpIcon = 'assets/icons/help.png';
  static const String historyIcon = 'assets/icons/history.png';
  static const String issueIcon = 'assets/icons/issue.png';
  static const String passwordIcon = 'assets/icons/password.png';
  static const String starIcon = 'assets/icons/star.png';
  static const String themeModeIcon = 'assets/icons/theme_mode.png';
  static const String verifiedIcon = 'assets/icons/verified.png';
  static const String verticalMenuIcon = 'assets/icons/vertical_menu.png';
  static const String folderIcon = 'assets/icons/folder.png';
  static const String videoIcon = 'assets/icons/video.png';
  static const String emailIcon = 'assets/icons/email.png';
  static const String editIcon = 'assets/icons/edit.png';
  static const String notificationIcon = 'assets/icons/bell.png';
  static const String closeIcon = 'assets/icons/close.png';

  // ============================================
  // COLORED ICONS
  // ============================================
  static const String documentIconColored = 'assets/icons/document_colored.png';
  static const String starIconColored = 'assets/icons/star_colored.png';
  static const String sortIconColored = 'assets/icons/sort_colored.png';
}
