import 'dart:async';
import 'package:aad_oauth/model/token.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide AndroidOptions;
import 'dart:convert' show jsonEncode, jsonDecode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  final FlutterSecureStorage _secureStorage;
  final String _tokenIdentifier;
  final Token emptyToken = Token();

  AuthStorage(
      {String tokenIdentifier = 'Token', required AndroidOptions aOptions})
      : _tokenIdentifier = tokenIdentifier,
        _secureStorage = FlutterSecureStorage(aOptions: aOptions);

  Future<void> saveTokenToCache(Token token) async {
    var data = Token.toJsonMap(token);
    var json = jsonEncode(data);
    await _secureStorage.write(key: _tokenIdentifier, value: json);
  }

  Future<void> saveCookies(List<Map<String,dynamic>> cookies) async{
    await _secureStorage.write(key: "${_tokenIdentifier}_cookie", value: jsonEncode(cookies));
  }

  Future<List<Cookie>> loadCookies() async{
    var json = await _secureStorage.read(key: "${_tokenIdentifier}_cookie");
    if (json == null) return [];
    try {
      var data = jsonDecode(json) as List<dynamic>;
      return data.map((e) {
        var mapped = Map<String,dynamic>.from(e);
        return Cookie(
          name: mapped["name"],
          value: mapped["value"],
          expiresDate: mapped["expiresDate"],
          isSessionOnly: mapped["isSessionOnly"],
          domain: mapped["domain"],
          sameSite: mapped["sameSite"],
          isSecure: mapped["isSecure"],
          isHttpOnly: mapped["isHttpOnly"],
          path: mapped["path"]
        );
      }).toList();
    } catch (exception) {
      print(exception);
      return [];
    }
  }

  Future<T> loadTokenFromCache<T extends Token>() async {
    var json = await _secureStorage.read(key: _tokenIdentifier);
    if (json == null) return emptyToken as FutureOr<T>;
    try {
      var data = jsonDecode(json);
      return _getTokenFromMap<T>(data) as FutureOr<T>;
    } catch (exception) {
      print(exception);
      return emptyToken as FutureOr<T>;
    }
  }

  Token _getTokenFromMap<T extends Token>(Map<String, dynamic> data) =>
      Token.fromJson(data);

  Future clear() async {
    await _secureStorage.delete(key: _tokenIdentifier);
  }
}
