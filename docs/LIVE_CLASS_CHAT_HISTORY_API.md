# API Spec — Live Class Chat History

**Status:** Not implemented on the backend. The Flutter app already calls this endpoint and gets `404`.
**Owner:** Backend (StreamApi / chat service)
**Consumer:** Crinza Flutter app — already written, needs zero app changes once this ships.

---

## 1. The problem this solves

A student opens a live class, chats, leaves the room, and comes back — **the chat panel is empty**. All previous messages are gone.

Reason: chat messages are delivered live over the SignalR hub (`ReceiveMessage`), which only pushes messages sent *while you are connected*. On rejoin, the app asks the REST API for the recent history so it can repaint the conversation. That REST endpoint does not exist, so the panel starts blank every time.

Verified against production on 2026-08-07:

| Request | Result | Meaning |
|---|---|---|
| `GET https://api.crinza.com/api/stream/token` | `405` | Route exists (wrong method) — sanity check that this area of the API is live |
| `GET https://api.crinza.com/api/stream/live-classes/{roomId}/chat` | `404` | Route does not exist |
| Same path on `https://stream.crinza.com` | `404` | Not on the stream host either |

Tried numeric, GUID, and slug room ids — all `404`. A protected-but-existing route would return `401`, not `404`.

### The decisive comparison

All three live-stream routes share the same host and the same `/api/stream/` prefix. Two of them respond like real routes; the chat one does not exist on any HTTP method:

| Route | `GET` | `POST` | Verdict |
|---|---|---|---|
| `/api/stream/token` | `405` | `401` | **Exists** (POST-only, needs auth) |
| `/api/stream/live-classes/{roomId}/playback` | `401` | `405` | **Exists** (GET-only, needs auth) |
| `/api/stream/live-classes/{roomId}/chat` | `404` | `404` | **Missing** |

`playback` and `chat` sit under the *identical* path template with the identical room id — one authenticates, the other 404s. That rules out room-id format, auth, and routing prefix as explanations. The handler was simply never written.

### There is already a working precedent in this codebase

The **group chat** feature solves exactly this problem and works today:

| Route | Purpose | Probe result |
|---|---|---|
| `GET /api/v1/chat-group/{groupId}/messages` | Message history backfill | `500` on an invalid unauthenticated call — i.e. it **routes** |
| `POST /api/v1/generate-token-v2` | Dedicated chat token | `401` — exists |
| `DELETE /api/v1/chat-group/messages/{messageId}` | Delete a message | defined in app |

Group chat uses the same architecture as live-class chat — messages sent over SignalR, history fetched over REST — and its REST half exists. **The fastest path to a fix is to mirror `/api/v1/chat-group/{groupId}/messages` for live-class rooms**, including however it already persists messages.

---

## 2. Two things are required

**(a) Persist chat messages.** When the hub method `SendChat` is invoked, the message must be written to the database — not only broadcast in memory. If messages aren't stored, the history endpoint will correctly return an empty list forever.

**(b) Expose the history endpoint** described below.

Please confirm (a) explicitly — it's the part most likely to be missing, and it is invisible from the client side.

---

## 2b. The complete live-stream surface (for context)

The live class feature uses **three REST endpoints and one SignalR hub**. Only the chat history endpoint is missing.

**REST — host `https://api.crinza.com`, standard app JWT:**

| Method | Path | Purpose | Status |
|---|---|---|---|
| `POST` | `/api/stream/token` | Mints a short-lived StreamApi JWT used to authenticate the SignalR hub connection | Working |
| `GET` | `/api/stream/live-classes/{roomId}/playback` | Resolves the signed HLS playback URL for the class video | Working |
| `GET` | `/api/stream/live-classes/{roomId}/chat` | Chat history backfill | **← MISSING, this spec** |

**SignalR hub — `https://stream.crinza.com/hubs/class`**, authenticated with the stream token from `/api/stream/token`:

*Client → server methods:* `JoinRoom(roomId)`, `SendChat(body)`, `RaiseHand()`, `LowerHand()`, `StopSpeaking()`, `MicActivated()`

*Server → client events:* `roomState`, `ReceiveMessage` (chat push), `chatModeChanged`, `queuePosition`, `handLowered`, `micGranted`, `micExpired`, `micReleased`, `nowSpeaking`, `speakerEnded`, `flagUpdated`, `kicked`, `classStarted`, `classEnded`, `classCancelled`, `actionDenied`

**Note there is no REST endpoint for *sending* live-class chat** — sending happens exclusively through the hub's `SendChat`. That is a fine design, but it means **the hub is the only place message persistence can happen**. Whoever implements the history endpoint must confirm `SendChat` writes to a table first.

---

## 3. Endpoint contract

```
GET /api/stream/live-classes/{roomId}/chat?beforeId={int}&limit={int}
```

**Host:** `https://api.crinza.com` (the app's main `BASE_URL` — *not* the stream host; the app's regular API client makes this call).

**Auth:** Standard app JWT as `Authorization: Bearer <token>` — the same token used for every other `/api/...` call. This is **not** the short-lived stream token. Return `401` if absent/invalid.

### Path parameter

| Name | Type | Notes |
|---|---|---|
| `roomId` | string | Passed through verbatim from the live-class room identifier the app already uses to join the SignalR hub and to resolve playback. Whatever identifier `SendChat` stores messages against is the correct one here — they must match. |

### Query parameters

| Name | Type | Required | Behavior |
|---|---|---|---|
| `limit` | int | No | Max messages to return. App sends `30`. Default to `30` if omitted; cap server-side at e.g. `100`. |
| `beforeId` | int | No | Pagination cursor. When present, return only messages with `id < beforeId`. When absent, return the **most recent** page. |

### Ordering (important)

Return the **newest `limit` messages**, i.e. `WHERE roomId = @roomId AND (@beforeId IS NULL OR id < @beforeId) ORDER BY id DESC LIMIT @limit`.

The app re-sorts newest-first on its side, so either ordering *within the page* is tolerated — but the page itself must be the newest slice, not the oldest. Returning the first 30 messages ever sent would show stale chat at the top of a long-running class.

---

## 4. Response shape

`200 OK`, standard envelope used elsewhere in the API:

```json
{
  "success": true,
  "message": "OK",
  "data": [
    {
      "id": 1841,
      "senderId": 226,
      "senderRole": "student",
      "senderName": "Aditi Sharma",
      "body": "is the recording available later?",
      "createdAt": "2026-08-07T11:42:09Z"
    },
    {
      "id": 1840,
      "senderId": 12,
      "senderRole": "educator",
      "senderName": "Rahul Verma",
      "body": "We'll start in 2 minutes.",
      "createdAt": "2026-08-07T11:41:55Z"
    }
  ]
}
```

Empty history → `"data": []` with `200`. Do **not** return `404` for a room with no messages.

### Field reference

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | int | **Yes** | Unique, monotonically increasing per message. Used both for de-duplication against live hub messages and as the `beforeId` pagination cursor. **Must be a real non-zero id** — if it's missing or `0`, pagination breaks and duplicates appear. |
| `senderId` | int | **Yes** | The sender's user id, matching the id claim in the app JWT. The app compares this to the logged-in user to identify "my own messages" (used for bubble alignment and private-mode filtering). |
| `senderRole` | string | **Yes** | `"student"` or `"educator"`. Anything that is not `student`/`learner` is treated as the educator. Getting this wrong makes teacher messages disappear in private chat mode. |
| `senderName` | string | Yes | Display name shown on the bubble. |
| `body` | string | **Yes** | The message text. |
| `createdAt` | string | Yes | ISO-8601 timestamp, UTC preferred (`2026-08-07T11:42:09Z`). The app converts to local time. |

**Field naming is flexible but consistency matters.** The app accepts common aliases (`message`/`text`/`content` for `body`; `userId`/`studentId` for `senderId`; `role`/`senderType` for `senderRole`; `created_at`/`timestamp`/`sentAt` for `createdAt`). Prefer the canonical names in the table. Critically: **the history response and the hub's `ReceiveMessage` payload must describe the same message the same way** — especially `id`, so a message received live isn't shown twice after a reconnect re-fetch.

### Envelope tolerance

The app unwraps `data` as a list, and also handles the list nested under `data.items` / `data.messages` / `data.chats` / `data.history` / `data.results` / `data.records`. Any of those work; a flat `data` array is preferred.

---

## 5. Error handling

| Situation | Status | App behavior |
|---|---|---|
| Success (incl. no messages) | `200` + `data: []` | Renders chat (or empty panel) |
| Missing/invalid token | `401` | Standard auth handling |
| Student not enrolled / no access to room | `403` | Chat stays empty |
| Room id doesn't exist | `404` | Chat stays empty |
| Server error | `500` | Chat stays empty, class video unaffected |

Chat history failures are **non-fatal** on the client — video playback and hand-raise keep working. So a failure here degrades gracefully, but silently; that's exactly why this bug went unnoticed.

---

## 6. Retention / privacy notes for whoever builds this

- **Retention:** decide how long messages persist (e.g. keep for the life of the class + N days). If messages are purged when the class ends, rejoining an ended class will show empty chat — that may be intentional, just make it a decision rather than an accident.
- **Private chat mode:** the room has a chat mode where students only see educator messages plus their own. The app filters client-side already, but server-side filtering on the history response is safer if the backend knows the requester's identity and the room's current mode. If you filter server-side, make sure the user's own messages are still included.
- **Moderation:** if messages can be deleted/hidden by a moderator, exclude them from history (or include a flag) — the app has no concept of a deleted live-class message today.

---

## 7. Acceptance test

1. Student A joins live class, sends 3 messages. Educator sends 2.
2. Student A leaves the room entirely and rejoins.
3. **Expected:** all 5 messages are visible immediately, newest at the top, correct names and sides.
4. Scroll up in a room with 50+ messages → older pages load via `beforeId` without duplicates or gaps.
5. Send a new message while scrolled through history → it appears once (not twice).

**How the app confirms it:** run `fvm flutter run` and watch the console. Today it prints:

```
[ClassChat] history FETCH FAILED → ...404...
```

After this ships it should print:

```
[ClassChat] history raw={success: true, data: [...]}
[ClassChat] history fetched count=5
```

---

## 8. Flutter-side references (already implemented, no changes needed)

| What | Where |
|---|---|
| Endpoint path constant | `lib/core/network/api_endpoints.dart` → `liveClassChat` |
| HTTP call (Retrofit) | `lib/core/network/api_client.dart` → `getLiveClassChat` |
| Response parsing / envelope tolerance | `lib/features/courses/data/repositories/course_repository_impl.dart` → `getLiveClassChat` |
| Message model + field aliases | `lib/features/courses/data/models/live_class_models.dart` → `LiveChatMessage.fromJson` |
| Fetch on join / reconnect, pagination, de-dup | `lib/features/courses/presentation/bloc/live_class_cubit.dart` → `_loadInitialChat`, `loadMoreChat`, `_onIncomingChat` |

The client calls this endpoint on room entry, on SignalR reconnect, and when chat mode switches back to public — so once the endpoint returns data, history appears in all three cases with no app release required.
