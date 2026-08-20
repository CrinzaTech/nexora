/// A downloaded payment receipt — the raw HTML document plus the
/// filename the server suggested via `Content-Disposition`.
class ReceiptModel {
  final String html;
  final String filename;

  const ReceiptModel({required this.html, required this.filename});
}
