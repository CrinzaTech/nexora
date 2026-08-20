import 'package:dartz/dartz.dart';

import 'package:nexora/core/error/failures.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/webinar/data/models/webinar_model.dart';
import 'package:nexora/features/webinar/data/models/webinar_payment_model.dart';

abstract class WebinarRepository {
  /// `GET /api/v1/webinars` — live and upcoming webinars for the
  /// learner's organization. An empty page is a normal 200, not an
  /// error, and the server's ordering (live first, then soonest) is
  /// authoritative.
  Future<Either<Failure, WebinarPage>> getWebinars({
    int pageNo = 1,
    int pageSize = 10,
  });

  /// `GET /api/v1/webinars/{slug}` — one webinar, including the org
  /// branding and the join gate. Still answers for ended and cancelled
  /// webinars, so a stale card gets an explanation rather than a 404.
  Future<Either<Failure, WebinarDetail>> getWebinarDetail(String slug);

  /// `POST /api/v1/webinars/{slug}/join` — takes the seat on the account
  /// token. This is the app's entire registration step: the learner is
  /// already an account, so there is no form and no OTP.
  ///
  /// Idempotent, and returns the same payload as [getWebinarState], so
  /// the caller can route straight to the lobby or the player.
  Future<Either<Failure, WebinarSessionState>> joinWebinar(String slug);

  /// `GET /api/v1/webinars/{slug}/state` — the lobby poll.
  Future<Either<Failure, WebinarSessionState>> getWebinarState(String slug);

  /// `GET /api/v1/webinars/{slug}/playback` — a signed, short-lived HLS
  /// URL. Also records attendance, which is what tells "registered but
  /// never showed up" from "joined".
  Future<Either<Failure, String>> getWebinarPlayback(String slug);

  /// `GET /api/v1/webinars/{slug}/chat` — newest first. [beforeId] is an
  /// exclusive cursor for paging backwards.
  Future<Either<Failure, List<LiveChatMessage>>> getWebinarChat(
    String slug, {
    int? beforeId,
    int limit = 30,
  });

  /// `POST /api/v1/webinars/{slug}/hub-token` — a **StreamApi** token
  /// for the chat socket, not an API token. Mint it per connection
  /// attempt; it is short-lived enough that one cached at entry is dead
  /// by the time a reconnect needs it.
  Future<Either<Failure, String>> getWebinarHubToken(String slug);

  /// `POST /api/v1/webinars/{slug}/create-order` — P1. Only for a paid
  /// webinar the learner has not bought: it 400s on a free one and 403s
  /// once they own it, both of which are branching mistakes upstream
  /// rather than errors to show.
  Future<Either<Failure, WebinarOrder>> createWebinarOrder(String slug);

  /// `POST /api/v1/webinars/{slug}/verify-payment` — P2, **the only
  /// thing that grants a seat.** A completed Razorpay sheet is not a
  /// purchase until this returns `paid: true`.
  ///
  /// The three ids are forwarded exactly as Razorpay handed them over —
  /// the signature is an HMAC over the other two, so any reformatting
  /// makes it fail to verify.
  Future<Either<Failure, WebinarPaymentResult>> verifyWebinarPayment(
    String slug, {
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });
}
