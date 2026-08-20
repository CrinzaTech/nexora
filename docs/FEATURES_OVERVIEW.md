# Crinza — Feature Overview

**A complete mobile Learning Management System (LMS) for Android and iOS.**

Crinza lets an institute sell and deliver online courses end-to-end — from the moment a student signs up, through payment, live and recorded classes, exams and assignments, right up to certificates of completion and support. Everything runs inside one branded app that the institute controls.

---

## 1. Sign-up & Login

| Feature | What the student sees |
|---|---|
| **OTP login** | Enter mobile number or email → receive a one-time code → logged in. No passwords to remember or reset. |
| **Auto-read OTP** | On Android the code fills itself in automatically. No switching to the SMS app. |
| **Institute code** | Students enter their organisation's code so the app loads the right institute's courses and branding. |
| **Profile setup** | First-time users complete name, email, photo and basic details in a guided screen. |
| **Secure session** | The login is stored in the phone's hardware-protected keychain and stays signed in between visits. |

---

## 2. Home & Course Discovery

- **Personalised home screen** — welcome banner, promotional banners with tap-through actions, and a live notification counter.
- **Continue Learning** — resume the last-watched lecture with one tap from the home screen.
- **Continue your purchase** — courses a student browsed but didn't buy are resurfaced with a Buy Now shortcut.
- **Educator / category tiles** — browse courses grouped by faculty or subject.
- **Trending & New courses** — curated rails, refreshed from the admin panel.
- **Learner reviews on home** — real student testimonials with star ratings, driving trust.
- **Social media links** — direct links to the institute's channels.
- **Full catalog** — browse every course with category chips, filters and sorting.
- **Search** — instant search across all courses, with results as you type.

---

## 3. Course Page & Purchase

- **Rich course detail** — thumbnail, description, module-by-module curriculum, faculty info, ratings and reviews.
- **Free demo/preview** — students can watch selected lessons before paying.
- **Ratings & reviews** — students rate the course and write a review after enrolling; ratings show publicly.
- **Flexible pricing plans** — one course can offer multiple price tiers (e.g. 6-month vs 1-year validity). Students pick from a plan sheet.
- **Transparent price breakdown** — base price, discount/coupon, tax, platform fee and final payable amount shown before payment.
- **Coupons & 100%-off** — discount codes are supported; a fully discounted course enrols instantly with no payment screen.
- **Razorpay checkout** — UPI, cards, net banking, wallets. Student details are pre-filled.
- **Verified payments** — every payment is confirmed on our server before access is granted, so access can never be faked from the phone.
- **Transaction history & receipts** — students see all past purchases and can download a receipt PDF.

---

## 4. Learning Content

The curriculum supports **nine types of content**, all inside one player experience:

| Content type | Support |
|---|---|
| **Folders / modules** | Nested chapter structure |
| **Video lectures** | Streaming video with custom branded player — including YouTube-hosted videos played without any YouTube branding, logo or "Watch on YouTube" link |
| **Live classes** | Real-time streaming (details in §5) |
| **PDFs** | In-app PDF reader — no download needed |
| **Images** | Full-screen image viewer with zoom |
| **Documents** | In-app document viewer |
| **ZIP / resources** | Downloadable material |
| **Assignments** | Submit files, get graded (§7) |
| **Exams / tests** | Full online test engine (§6) |

**Progress tracking** — the app automatically records a lesson as complete once the student has genuinely watched/read enough of it (75% threshold), so progress percentages are real, not self-declared.

**My Courses** — purchased courses split into **In Progress** and **Completed** tabs, with search, progress bars, validity/expiry dates and a **Rewatch** option for finished courses.

---

## 5. Live Classes ⭐

This is the most advanced part of the app.

- **Live video streaming** with a low-latency player tuned specifically for live cadence.
- **Live chat** during class — students and faculty talk in real time alongside the video.
- **Raise Hand → Speak** — a student raises their hand, joins a queue (with their position shown), and once the teacher approves, their microphone opens and they speak to the whole class live. Audio only — a student's camera is never used.
- **Automatic audio-only fallback** — on a weak network the app silently drops from video to audio-only (~48 kbps instead of ~850 kbps) so the class never cuts out. It switches back automatically when the connection recovers.
- **Background audio** — the student can lock the phone or switch apps and keep hearing the class, with playback controls on the lock screen.
- **Landscape mode** — full-screen video with a floating chat panel and quick-action controls that never eat into the video.
- **Screen stays awake** for the whole class — no dimming or locking mid-session.
- **Auto-recovery** — if the stream errors or the app was backgrounded too long, the player automatically rejoins at the live edge instead of showing an error.

---

## 6. Online Exams & Tests ⭐

A complete competitive-exam-grade test engine:

- **Sectioned papers** — multi-section exams (e.g. Reasoning / Maths / English) with section transitions.
- **Live countdown timer** with per-exam duration.
- **Negative marking** support.
- **Rich question formatting** — formatted text, lists and bold/italics rendered exactly as authored.
- **Auto-save** — answers are saved as the student goes, so a crash or disconnect never loses their attempt.
- **Instant results** — score, correct/incorrect breakdown and performance summary right after submission.
- **Attempt history** — students see all previous attempts of the same test.
- **Re-attempt** — retake a test where the institute allows it.
- **Eligibility gate** — the server decides who may start a test and when.

---

## 7. Assignments

- **View the assignment** — question paper shown in-app as PDF or image.
- **Submit files** — attach a PDF or image directly from the phone.
- **Live deadline countdown** — the student always sees exactly how much time is left.
- **Auto-submit at deadline** — if a student has picked a file but not submitted, it is submitted automatically when time runs out. Nothing is lost to a missed tap.
- **Resubmit before deadline** — replace a submission any number of times while the window is open; the latest one always counts.
- **Grading** — the score and feedback from the institute appear in the app once graded.

---

## 8. Community Chat

- **Group chat rooms** — real-time messaging per batch/course, powered by a live socket connection (not polling).
- **Instant delivery** — messages, deletions and typing indicators appear live.
- **Announcement-only groups** — read-only groups where only faculty can post.
- **Message moderation** — messages can be deleted.
- **Chat history** — full past conversation loads on open.
- **Access control** — chat groups are gated to paid students.

---

## 9. Notifications

- **Push notifications** — course updates, live class alerts, offers, reminders — delivered even when the app is closed.
- **In-app notification centre** — full list with images, read/unread status and timestamps ("10:50 AM", "Yesterday", "12 Apr").
- **Smart tap-through** — tapping a notification opens the exact course, live class, or web link it refers to, from any app state including a cold start.
- **Unread badge** on the home screen bell.

---

## 10. Profile & Support

- **Edit profile** — name, email, photo and details.
- **Transaction history** with downloadable receipts.
- **Contact support** — direct WhatsApp / call / email links to the institute.
- **Rate our App** — routes to the Play Store / App Store listing.
- **Share App** — native share sheet (WhatsApp, Messages, Mail) for word-of-mouth growth.
- **Terms & Conditions / Refund Policy** — in-app legal pages.
- **Secure logout** with confirmation.

---

## 11. Content Protection & Anti-Piracy ⭐

Course content is protected at **four independent layers** — this is a core differentiator:

1. **Screenshot & screen-recording blocked (Android)** — enforced by the operating system itself, not by the app. Screenshots come out black and screen recorders capture nothing.
2. **Screen-recording detection (iOS)** — when iOS reports the screen is being captured or mirrored, the app instantly blacks out the content.
3. **Compromised-device blocking** — the app refuses to run on rooted/jailbroken phones or devices with Developer Mode enabled, and re-checks every time the app returns to the foreground. There is no way to navigate past the block screen.
4. **Moving identity watermark** — the student's own name and phone number drift continuously across every video. Any leaked recording carries the identity of the person who leaked it.

Protection is **on by default** — it engages before the app even finishes loading, and can only be relaxed per-user from the admin side.

---

## 12. Platform & Reliability

- **Android and iOS** from a single codebase — one build, both stores.
- **White-label / multi-brand** — logo, app name, colours and splash screen are driven from configuration. The same app can be re-skinned for another institute without rewriting code.
- **Crash reporting (Firebase Crashlytics)** — every crash is captured with full context so issues are found and fixed before students report them.
- **Graceful failure** — if any part of the app fails to start, the rest still works; the student lands on a usable screen, never a blank crash.
- **Clear network errors** — "No internet connection", "Connection timed out" and real server messages instead of raw error codes.
- **Polished loading states** — shimmer placeholders instead of blank spinners.
- **Pull-to-refresh** across all list screens.
- **Responsive design** — adapts to every phone size, and live classes support both portrait and landscape.

---

## In One Line

> **Crinza is a production-ready, white-label mobile LMS that handles OTP onboarding, course discovery, online payments, recorded and live classes with interactive raise-hand audio, a full competitive-exam test engine, assignment submission with grading, real-time community chat, push notifications — all protected by four layers of anti-piracy security.**
