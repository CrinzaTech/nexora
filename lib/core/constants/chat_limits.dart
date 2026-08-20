/// Time windows for editing and deleting chat messages.
///
/// **The server is the authority.** `edit_chat_message` and
/// `delete_chat_message` apply these windows in SQL and refuse anything
/// outside them (`403` for a late edit, `404` for a late delete).
/// Changing the numbers here alone changes nothing — it only moves when
/// the app stops *offering* the action.
///
/// Both windows are anchored on the message's `createdAt`, never on
/// `editedAt`: anchoring on the edit time would let an author edit
/// repeatedly to extend their own window forever.
///
/// They live in one place so a product change is a single edit rather
/// than a hunt through the room page, the bubble and the cubit.
class ChatLimits {
  const ChatLimits._();

  /// How long after sending an author may still edit their message.
  static const Duration editWindow = Duration(minutes: 2);

  /// How long after sending an author may still delete their message.
  /// A delete removes it for **both** sides.
  static const Duration deleteWindow = Duration(hours: 24);
}
