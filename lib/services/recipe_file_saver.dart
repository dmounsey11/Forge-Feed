// Downloads/saves the recipe as a text file. Real implementation on web
// (dart.library.html); falls back to an honest "not available yet" on
// other platforms rather than silently doing nothing. See
// recipe_file_saver_web.dart / recipe_file_saver_stub.dart.
export 'recipe_file_saver_stub.dart' if (dart.library.html) 'recipe_file_saver_web.dart';
