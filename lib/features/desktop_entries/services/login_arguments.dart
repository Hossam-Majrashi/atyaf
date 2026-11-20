import 'dart:convert';

/// Additional arguments used only for an explicitly configured login launch.
class LoginArguments {
  static const option = '--login-arguments';
  static const _maxLength = 4096;
  static final _token = RegExp(r'^[A-Za-z0-9_-]+={0,2}$');

  static List<String> parse(String json) {
    if (json.length > _maxLength || utf8.encode(json).length > _maxLength) {
      throw const FormatException('Login arguments exceed the size limit');
    }
    final value = jsonDecode(json);
    if (value is! List ||
        value.isEmpty ||
        value.length > 32 ||
        value.any((v) => v is! String || v.contains('\x00')) ||
        !value.any((v) => (v as String).trim().isNotEmpty)) {
      throw const FormatException('Invalid login arguments');
    }
    return List<String>.unmodifiable(value);
  }

  static String encode(List<String> arguments) {
    final json = jsonEncode(arguments);
    parse(json);
    return base64Url.encode(utf8.encode(json));
  }

  static List<String> decode(String token) {
    if (token.length > ((_maxLength + 2) ~/ 3) * 4 || !_token.hasMatch(token)) {
      throw const FormatException('Invalid login argument encoding');
    }
    return parse(utf8.decode(base64Url.decode(token)));
  }

  static List<String> combine(List<String> regular, List<String> login) {
    final separator = regular.indexOf('--');
    final index = separator < 0 ? regular.length : separator;
    return [...regular.take(index), ...login, ...regular.skip(index)];
  }
}
