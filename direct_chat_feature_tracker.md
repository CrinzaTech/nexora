# Personal Chat (1-to-1) — Feature Tracker

Companion to `chat_feature_tracker.md`. Source of truth for the plan:
`PERSONAL_CHAT_FLUTTER_GUIDE.md` (repo root).

**Status legend**
| Mark | Meaning |
|---|---|
| 🟢 | Shipped and wired end-to-end |
| 🟡 | Partially done — see note |
| ⚪ | Not started |
| ⏭️ | Deliberately deferred — see §11 |

**Update rule:** every status flip gets a `file:line` pointer.

---

## 1. Auth & chat token

| # | Item | Status | Pointer / note |
|---|---|---|---|
| 1.1 | Reuse the existing chat token — no second mint | 🟢 | `ChatTokenProvider` is the single owner: `lib/features/chats/data/services/chat_token_provider.dart:20` |
| 1.2 | Shared `ChatTokenProvider` extracted (guide §7.2 recommended path) | 🟢 | `chat_token_provider.dart:31` (`generateToken`), `:62` (`ensureBearer`) |
| 1.3 | `ChatGroupRepositoryImpl` delegates rather than duplicating | 🟢 | `chat_group_repository_impl.dart:39` — public contract unchanged |
| 1.4 | `_resolveStudentName` moved with it | 🟢 | `chat_token_provider.dart:78` |
| 1.5 | DI registration | 🟢 | `dependency_injection.dart` — `ChatTokenProvider` registered before both repos |

## 2. SignalR transport (extends the existing service — one connection)

| # | Item | Status | Pointer / note |
|---|---|---|---|
| 2.1 | `_activeConversationKey` field | 🟢 | `signalr_chat_service.dart` — tracked alongside `_activeGroupId` |
| 2.2 | Re-join the conversation on `onreconnected` | 🟢 | Both the group room *and* the DM thread are re-joined |
| 2.3 | `JoinConversation` / `LeaveConversation` | 🟢 | Mirror `joinGroup`/`leaveGroup`, including the not-connected skip |
| 2.4 | `SendDirectMessage` (camelCase payload map) | 🟢 | Sends `messageType: 'Text'` via `.wireValue`, same as group chat |
| 2.5 | `MarkDirectRead` (two positional args) | 🟢 | |
| 2.6 | `StartTypingDirect` / `StopTypingDirect` | 🟢 | |
| 2.7 | Eight `connection.on` handlers | 🟢 | `ReceiveDirectMessage`, `DirectMessageEdited`, `DirectInboxUpdated`, `DirectMessageDeleted`, `DirectUserTyping`, `DirectUserStoppedTyping`, `DirectMessagesRead`, `DirectConversationBlockChanged` |
| 2.8 | `Map<dynamic,dynamic>` coercion on every new handler | 🟢 | All route through the existing `_firstMap` |
| 2.9 | Seven new stream controllers created **and** closed in `dispose()` | 🟢 | |
| 2.10 | Distinct event payload types (no `groupId`/`conversationKey` mixups) | 🟢 | `DirectMessageDeletedEvent`, `DirectTypingEvent`, `DirectMessagesReadEvent`, `DirectBlockChangedEvent` |

## 3. REST APIs

Base `/api/v1/direct-chat`. Declarations in `api_client.dart`; **hand-written**
implementations in `api_client.g.dart` (retrofit_generator is excluded from this
repo — see the header comment in `api_client.dart`).

| # | Endpoint | Status | Note |
|---|---|---|---|
| 3.1 | `GET /conversations` | 🟢 | Bare array → `Future<List<dynamic>>` |
| 3.2 | `POST /conversations` | 🟢 | Idempotent; 404 mapped to "This person is not available for messaging." |
| 3.3 | `GET /directory` | 🟢 | Bare array |
| 3.4 | `GET /conversations/{key}/messages` | 🟢 | Parsed by `PagedChatMessages.fromJson` unchanged |
| 3.5 | `GET /conversations/{key}/unread-count` | 🟢 | |
| 3.6 | `POST /conversations/{key}/read` | 🟢 | `204` → `Future<void>` |
| 3.7 | `DELETE /messages/{messageId}` | 🟢 | `204` → `Future<void>`. Late delete's `404` remapped to window copy. |
| 3.8 | `PUT /messages/{messageId}` (edit) | 🟢 | Returns the updated message; `403`/`400` remapped to the admin-panel wording |
| 3.9 | `POST /conversations/{key}/clear` | 🟢 | Returns `clearedUpToMessageId` |
| 3.10 | `POST /conversations/{key}/block` | ⏭️ | Staff-only; a learner gets 403. Deliberately not called. |
| 3.11 | Key encoding | 🟢 | `_encodeKey` applied to **path** params only — query params are left raw so Dio encodes them exactly once (`direct_chat_repository_impl.dart:24`). The edit call carries the key in the **JSON body**, so it goes raw there too. |

## 4. Models

| # | Item | Status | Pointer / note |
|---|---|---|---|
| 4.1 | `DmConversation` + tolerant `fromJson` | 🟢 | `dm_conversation_model.dart` — numeric/string ids, `.toLocal()` on `lastMessageAt` |
| 4.2 | `DmDirectoryEntry` | 🟢 | same file |
| 4.3 | `copyWith` for local badge / block updates | 🟢 | |
| 4.4 | `initialsOf()` avatar fallback | 🟢 | Staff have no image column — initials are the real render path |
| 4.5 | `ChatMessage` / `PagedChatMessages` reused verbatim | 🟢 | No fork. `ChatMessage.groupId` carries the conversation key (shared table). |
| 4.6 | `isFromCurrentStudent` correctness | 🟢 | It's a *role* check (`senderType == student`), which is exactly right here: this app is always the learner side of a student↔staff thread. It would misattribute a learner↔learner DM — see §11. |
| 4.7 | `ChatMessage.editedAt` (nullable) + `isEdited` | 🟢 | Parsed via a dedicated `parseNullableDate` — an absent value must stay null, not fall back to "now" like `createdAt` does |
| 4.8 | `canEdit` / `canDelete` window getters | 🟢 | On `ChatMessage`, reading `ChatLimits`. **Time-dependent — never cache.** |
| 4.9 | `ChatLimits` — windows in one file | 🟢 | `lib/core/constants/chat_limits.dart`. Server still owns enforcement. |
| 4.10 | `copyWith` extended for `message` / `editedAt` | 🟢 | |

## 4b. Edit / delete / clear — the three operations

The single most important thing to keep straight, because two of these look
alike in the UI and only one of them touches the other person's copy.

| | Delete a message | Clear history | Edit a message |
|---|---|---|---|
| Scope | One message | Whole thread | One message |
| Affects | **Both sides** | **Caller only** | Both sides |
| Window | 24 hours | none | **2 minutes** |
| Who | Author only | Anyone, own view | **Author only**, text only |
| Reversible | No | Yes (server-side) | n/a |
| Broadcast | `DirectMessageDeleted` → other party | **none, by design** | `DirectMessageEdited` → both |

| # | Item | Status | Pointer / note |
|---|---|---|---|
| 4b.1 | Long-press menu with Reply / Edit / Delete | 🟢 | `message_actions_sheet.dart` |
| 4b.2 | Menu built at open time, not cached | 🟢 | `MessageActionsSheet.show` is called per long-press, so the windows are evaluated against the clock *now*. Chosen over a 60 s ticker: same guarantee, no timer to leak. |
| 4b.3 | Edit hidden on staff bubbles and non-text messages | 🟢 | `ChatMessage.canEdit` |
| 4b.4 | Edit hidden after 2 min, Delete after 24 h | 🟢 | Same getters |
| 4b.5 | Inert long-press when no action applies | 🟢 | `show()` resolves to null without opening an empty sheet |
| 4b.6 | Composer preloads the text, with cancel | 🟢 | `ChatInput.initialText` + a `ValueKey` to force a fresh State; edit banner reuses `ReplyBanner` via `labelBuilder` |
| 4b.7 | Empty edit refused with a message, **not** converted to a delete | 🟢 | `ChatInput.allowEmptySubmit` keeps the button live in edit mode so `saveEdit('')` can explain itself. A dead button would have refused silently. |
| 4b.8 | No-op edit short-circuits | 🟢 | Unchanged text doesn't spend a round-trip or stamp `editedAt` |
| 4b.9 | `DirectMessageEdited` replaces in place by id | 🟢 | `_replaceMessage`; idempotent, so the REST response and the echo can both apply |
| 4b.10 | Delete confirm — "removed for the educator as well" | 🟢 | `ChatConfirmDialog.deleteMessage` |
| 4b.11 | Clear confirm — "hidden from your side only" | 🟢 | `ChatConfirmDialog.clearHistory`, from the thread overflow menu |
| 4b.12 | Clear is a server call, not a local list reset | 🟢 | `DirectChatRepository.clearHistory`; survives reinstall |
| 4b.13 | After clear: thread empties, inbox preview → blank, unread → 0 | 🟢 | `DirectInboxCubit.markThreadCleared`; `hasMore` also forced false since nothing older remains visible |
| 4b.14 | Caller gets no broadcast for own delete/clear | 🟢 | Local removal runs on the REST success path, and is idempotent if the server does echo |
| 4b.15 | Late-window / clock-skew refusals surface | 🟢 | `403`/`404`/`400` remapped in the repo, shown via `sendError` → snackbar |
| 4b.16 | Quoted reply previews don't live-patch on edit | 🟡 | Known and accepted per guide §5.7 — a rendered quote keeps the old text until reload, because the preview is joined server-side at read time |

## 5. State management

| # | Item | Status | Pointer / note |
|---|---|---|---|
| 5.1 | `DirectInboxCubit` as a lazy **singleton** | 🟢 | `dependency_injection.dart`; screens must use `BlocProvider.value` |
| 5.2 | Subscribed to `DirectInboxUpdated` for the app's lifetime | 🟢 | Wired in the constructor, not in `load()`, so a failed first fetch doesn't also cost real-time |
| 5.3 | Live block changes reflected in the inbox | 🟢 | `_onBlockChanged` |
| 5.4 | Server ordering re-applied on pushed updates | 🟢 | `_upsert` sorts newest-first, never-used threads to the top |
| 5.5 | `openWith(entry)` — reuse-or-create | 🟢 | Checks the precomputed `conversationKey` before spending a POST |
| 5.6 | `DirectChatRoomCubit` open / loadMore / send / markRead / close | 🟢 | Same six-step `open()` flow as `ChatRoomCubit` |
| 5.7 | Incoming dedup by id | 🟢 | The sender receives their own echo, exactly as in group chat |
| 5.8 | No badge flash while inside a thread | 🟢 | Room cubit calls `inbox.clearUnread()` **and** `markDirectRead` |
| 5.9 | `isBlocked` on the room state, live from the hub | 🟢 | Not a route param — staff can flip it mid-session |

## 6. UI / screens

| # | Item | Status | Pointer / note |
|---|---|---|---|
| 6.1 | Inbox page with unread pills + "Closed" chips | 🟢 | `direct_chat_inbox_page.dart`, `dm_conversation_tile.dart` |
| 6.2 | Auto-open when the org has a single staff member | 🟢 | `_shouldAutoOpen` — `pushReplacement`, so "back" returns to Profile. Shimmer is held through the resolve so a one-row list never flashes. |
| 6.3 | Staff picker bottom sheet | 🟢 | `staff_picker_sheet.dart`; FAB only appears with 2+ staff |
| 6.4 | Room page reusing `MessageBubble` / `ChatInput` / `SwipeToReply` | 🟢 | `direct_chat_room_page.dart` — no forked bubble code |
| 6.5 | `ReplyBanner` decoupled from `ChatRoomCubit` | 🟢 | Now takes `ValueListenable<ChatMessage?>` + `onCancel`, so both features share one widget. Group-chat call site updated. |
| 6.6 | Blocked composer state, live-updated | 🟢 | `_BlockedNotice` + disabled `ChatInput`, driven off `DirectConversationBlockChanged` |
| 6.7 | Loading / empty / error states | 🟢 | Reuses `ChatsListShimmer` and `ErrorState` |
| 6.8 | Initials avatar | 🟢 | `dm_avatar.dart` — scales the glyph with the circle |
| 6.9 | Relative timestamps on inbox rows | 🟢 | Today → clock, yesterday → "Yesterday", <7d → weekday, else short date |
| 6.10 | Long-press delete on own messages | 🟢 | See §4b |
| 6.11 | "edited" marker beside the timestamp | 🟢 | `_BubbleTimestamp` renders "edited · 2:47 PM"; the text bubble's timestamp reserve widens 56 → 96 px when edited so the last line doesn't run under it |
| 6.12 | Thread overflow menu → Clear my chat history | 🟢 | `_ThreadAction` in `direct_chat_room_page.dart` |
| 6.13 | Read-receipt ticks | ⚪ | `onDirectMessagesRead` is plumbed to the service but nothing renders it |

## 7. Navigation

| # | Item | Status | Pointer / note |
|---|---|---|---|
| 7.1 | `AppRoutes.directChatInbox = '/chats/direct'` | 🟢 | `app_routes.dart` |
| 7.2 | `AppRoutes.directChatRoom = '/chats/direct/room'` | 🟢 | |
| 7.3 | Query-param parser | 🟢 | `directChatRoomPageFromQuery` in `direct_chat_room_page.dart` |
| 7.4 | Routes registered | 🟢 | `app_router.dart`, next to `chat-room` |
| 7.5 | Entry point | 🟢 | **Profile → Help & Support → "Contact for Support"**, which branches on the org's `allowWhatsappSupport` flag: `true` → WhatsApp (unchanged), `false` → this feature's inbox. There is no separate "Personal Chat" tile — an org runs one support channel or the other, so a second entry would always be dead for somebody. |
| 7.6 | `OrgInfoModel.allowWhatsappSupport` | 🟢 | Defaults to `true` when the key is absent or unparseable, so an older backend keeps the existing WhatsApp behaviour instead of silently rerouting every org into chat |

## 8. DI

| # | Item | Status | Pointer / note |
|---|---|---|---|
| 8.1 | `ChatTokenProvider` lazy singleton | 🟢 | Registered before both chat repos |
| 8.2 | `DirectChatRepository` lazy singleton | 🟢 | |
| 8.3 | `DirectInboxCubit` lazy singleton | 🟢 | |
| 8.4 | `DirectChatRoomCubit` constructed inline by its page | 🟢 | Mirrors `ChatRoomCubit` |

## 9. Edge cases

| # | Item | Status | Note |
|---|---|---|---|
| 9.1 | Blocked send fails as an `Error` event, not an exception | 🟢 | Surfaced via `DirectChatRoomCubit.sendError` → snackbar. There is no optimistic bubble to roll back (neither chat renders one), so the composer disabling live is the primary defence. |
| 9.2 | The `Error` channel is shared with group chat | 🟡 | Accepted, per guide §8.3. Only one chat screen is active at a time. The real fix is a server-side `DirectError` event, not a client workaround. |
| 9.3 | Wi-Fi flip re-joins the open thread | 🟢 | `onreconnected` re-invokes `JoinConversation` |
| 9.4 | Directory fetch failure is soft | 🟢 | Existing threads stay readable; only the picker comes up empty |
| 9.5 | Auto-open failure doesn't strand the user | 🟢 | `_autoOpenResolved` is set on failure too, so the inbox renders with a retry path |
| 9.6 | A stale **chat** token 401 logs the user out of the whole app | 🟡 | Inherited from `auth_interceptor.dart` — same exposure group chat already has (`chat_feature_tracker.md` 9.2). Not made worse here, not fixed here. |
| 9.7 | Never construct a conversation key client-side | 🟢 | Keys only ever come from `/directory`, `/conversations`, or the POST response |
| 9.8 | Staff can be switched off individually (guide §5.3) | 🟢 | Nothing is persisted across launches — `DirectInboxCubit.load()` refetches both the directory and the inbox on every entry to the inbox page, so a switched-off staff member and their thread both vanish on the next open. No cached staff list, no cached key. |
| 9.9 | Thread open on screen when staff is switched off | 🟡 | The open room keeps rendering until the learner backs out; refreshing the inbox then drops it, which is the behaviour the guide's checklist asks for. There is no hub event for the toggle, so live eviction isn't possible without one. |
| 9.10 | Device clock is not trusted | 🟢 | The window getters only decide whether the *button* shows; the server compares against its own clock, and the resulting refusal is surfaced (4b.15) rather than assumed impossible |

## 10. Deviations from the guide

| # | Guide item | Decision |
|---|---|---|
| 10.1 | §7.3 "call `connect()` at app start / on login" | **Not done — deliberate.** The only consumer of `DirectInboxUpdated` today is the inbox screen itself, which connects in `DirectInboxCubit.load()`. There is no badge anywhere else in the app, so eager-connecting a websocket for every user at launch would buy nothing and cost a handshake on every cold start. Revisit the moment a badge lands on the Profile tile or the bottom nav — at that point this becomes required, not optional. |
| 10.2 | §7.4 "FAB or app-bar action opens the staff picker" | FAB, but **only when the directory has 2+ entries**. With one faculty member the learner is already in that thread and the button would be a dead end. |
| 10.3 | §7.5 "decide with the product owner: tab on Chats vs separate destination" | Separate destination, reached through the existing **"Contact for Support"** tile rather than a tab on `ChatsPage` or a tile of its own. The org's `allowWhatsappSupport` flag decides which of the two support channels that tile opens. |
| 10.4 | §5.8 "drive the windows from a periodic tick (the admin panel re-evaluates every 60 s)" | Menu is rebuilt **at open time** instead — the guide's stated alternative. Same guarantee for the affordance, with no timer to own or leak. Note the consequence: a menu left open across the 2-minute boundary still shows Edit; tapping it then gets a server `403`, which is surfaced. |
| 10.5 | §5.6 / §5.7 group-chat equivalents (`PUT /chat-group/messages/{id}`, `POST /chat-group/{groupId}/clear`, `MessageEdited`) | **Not built.** Scope is personal chat. `ChatMessage.editedAt` is on the shared model, so a group-chat message that comes back edited already renders its marker on reload — but group chat has no edit/delete/clear affordances and doesn't subscribe to `MessageEdited`. Ask for it explicitly; it is the same shape with a group id. |

## 11. Out of scope for this pass

- **Push notifications.** No FCM send exists for chat on any surface yet.
- **Learner-to-learner DMs.** Excluded backend-side; several queries assume the
  other participant is the opposite role. Note that `ChatMessage.isFromCurrentStudent`
  would need a real user-id check before this could ever work (see 4.6).
- **Media messages.** The wire format supports `image`/`file`/`audio` and
  `MessageBubble` already renders them, but neither chat has an upload path.
  Keep parity; don't build a DM-only media flow.
- **Block/unblock from the learner side.** Staff-only by design.

---

## 12. Verification checklist

Transport is written against a backend that had **not been exercised against a
live database** as of this pass — if a call 500s, suspect the stored procedures
before rewriting Dart.

- [x] `flutter analyze` clean (0 errors; 15 pre-existing warnings in untouched files)
- [x] `build_runner` regenerates both freezed states
- [ ] Learner opens a thread; staff replies from the admin panel; the bubble lands with no manual refresh
- [ ] Message arrives while on the **inbox** → badge increments via `DirectInboxUpdated`
- [ ] Message arrives while **inside** the thread → no badge flash, read receipt fires
- [ ] Both sides tap "start conversation" at once → exactly one thread exists
- [ ] Staff blocks the thread → composer disables **live**, history stays visible
- [ ] Send into a blocked thread → refusal surfaces as a snackbar
- [ ] Wi-Fi off then on → `onreconnected` re-joins, missed message arrives
- [ ] Learner edits their own message → new text appears on the admin panel live, "edited" marker on both sides
- [ ] Learner tries to edit an educator's message → no affordance offered
- [ ] Edit affordance disappears once 2 minutes have passed (reopen the menu)
- [ ] Emptying the text and tapping send → refusal message, **message not deleted**
- [ ] Learner deletes their own message → it disappears on the admin panel too
- [ ] Delete affordance gone after 24 hours
- [ ] Learner clears history → their thread empties, **the admin panel still shows everything** (this is the assertion that proves clear is not a delete)
- [ ] After clearing, the educator sends a new message → it appears normally
- [ ] Kill and reinstall, log back in → cleared messages are **still** hidden
- [ ] Admin switches a staff member's personal-chat toggle **off** → they vanish from the directory and the inbox on next open
- [ ] Toggle back **on** → staff member and thread reappear with full history
- [ ] Org with `allowWhatsappSupport: true` → "Contact for Support" still opens WhatsApp
- [ ] Org with `allowWhatsappSupport: false` → "Contact for Support" opens personal chat
- [ ] Backend that omits the flag entirely → falls back to WhatsApp, nothing changes
- [ ] Single-faculty org → support tile lands straight in the room; back returns to Profile
- [ ] Multi-faculty org → support tile shows the inbox; FAB opens the picker
- [ ] **Course group chat still works unchanged** — same connection, same service, and
      `ChatGroupRepositoryImpl`, `ReplyBanner`, `ChatInput`, `MessageBubble` and
      `ChatMessage` were all touched. Regression-test explicitly: send, reply, paginate.
- [ ] Logout wipes the chat token and disconnects
- [ ] Release build (R8) does not strip `signalr_netcore` reflection paths

---

## Changelog

| Date | Change |
|---|---|
| 2026-08-14 | Initial implementation. Transport, REST, models, state, UI, routing, DI and the Profile entry point all landed. `ChatTokenProvider` extracted from `ChatGroupRepositoryImpl`; `ReplyBanner` decoupled from `ChatRoomCubit`. |
| 2026-08-14 | Entry point moved. The standalone "Personal Chat" tile is gone; "Contact for Support" now branches on the org-info API's new `allowWhatsappSupport` flag — WhatsApp when true, this feature when false. `OrgInfoModel` gained the field with a `true` default. |
| 2026-08-14 | Guide updated with edit / delete / clear (§5.6–5.8), `DirectMessageEdited`, `editedAt`, and the staff toggle-off rule. Implemented all of it for personal chat: `ChatLimits`, `ChatMessage.editedAt` + window getters, "edited" marker, long-press actions sheet, edit composer mode, both confirm dialogs, thread-level clear. `ChatInput` gained `initialText` + `allowEmptySubmit`; `ReplyBanner` gained `labelBuilder`. Group-chat equivalents deliberately not built — see 10.5. |
