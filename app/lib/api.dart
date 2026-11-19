// Developed by Codesoftwares
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// flutter build apk --dart-define=API_BASE_URL=https://api.your-domain --dart-define=UPI_ID=name@bank
const apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');
const upiId = String.fromEnvironment('UPI_ID', defaultValue: 'set-your-upi-id@bank');

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
}

class Api {
  static String? token, role;
  static final signedOut = ValueNotifier<int>(0); // Root listens, so any screen can end the session
  static final session = ValueNotifier<int>(0); // changes on sign-in and sign-out (the website frame listens)
  static const _store = FlutterSecureStorage();
  static Map<String, String> get authHeaders => {'authorization': 'Bearer $token'};
  static String photoUrl(String id) => '$apiBase/photos/$id';

  static Future<void> restore() async {
    token = await _store.read(key: 'token');
    role = await _store.read(key: 'role');
  }

  static Future<void> save(String t, String r) async {
    token = t; role = r;
    await _store.write(key: 'token', value: t);
    await _store.write(key: 'role', value: r);
    session.value++;
  }

  static Future<void> signOut() async {
    token = null; role = null;
    await _store.deleteAll();
    signedOut.value++;
    session.value++;
  }

  static Future<Map<String, dynamic>> call(String method, String path, {Object? body}) async {
    final req = http.Request(method, Uri.parse('$apiBase$path'))
      ..headers.addAll({'content-type': 'application/json', if (token != null) ...authHeaders});
    if (body != null) req.body = jsonEncode(body);
    try {
      final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 20)));
      final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw ApiError(data['error'] as String? ?? 'Request failed. Please try again.');
      return data;
    } on ApiError {
      rethrow;
    } on TimeoutException {
      throw ApiError('The server took too long to answer. Please try again.');
    } on http.ClientException catch (e) {
      debugPrint('API ERROR [$method $path]: $e');
      throw ApiError('Cannot reach the server. Check your internet and try again.');
    } catch (e) {
      debugPrint('API ERROR [$method $path]: $e');
      throw ApiError('The server sent an unexpected reply (${e.runtimeType}). Please try again.');
    }
  }

  static Future<List<Map<String, dynamic>>> list(String path, [String key = 'items']) async =>
      ((await call('GET', path))[key] as List).cast<Map<String, dynamic>>();

  static Future<String> upload(String path, XFile f, {String method = 'POST'}) async =>
      (await call(method, path, body: {'data': base64Encode(await f.readAsBytes())}))['message'] as String;
}
