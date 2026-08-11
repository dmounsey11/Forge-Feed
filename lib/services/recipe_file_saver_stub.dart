/// Fallback for platforms without a web-style file download (desktop/mobile).
/// Returns false so the caller can show an honest "not available yet"
/// message instead of silently doing nothing.
Future<bool> downloadRecipeAsFile({required String filename, required String content}) async {
  return false;
}
