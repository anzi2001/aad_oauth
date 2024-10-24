import 'dart:async';

import 'package:aad_oauth/helper/auth_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'model/config.dart';
import 'request/authorization_request.dart';

class RequestCode {
  final Config _config;
  final AuthorizationRequest _authorizationRequest;
  final String _redirectUriHost;
  late InAppWebViewController _controller;
  final CookieManager _manager;
  final AuthStorage _authStorage;
  String? _code;

  RequestCode(Config config, AuthStorage storage)
      : _config = config,
        _authorizationRequest = AuthorizationRequest(config),
        _redirectUriHost = Uri.parse(config.redirectUri).host,
        _manager = CookieManager.instance(),
        _authStorage = storage;

  Future<String?> requestCode() async {
    _code = null;

    final urlParams = _constructUrlParams();
    final launchUri = Uri.parse('${_authorizationRequest.url}?$urlParams');

    final webView = InAppWebView(
      initialUrlRequest: URLRequest(url: launchUri),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          useShouldOverrideUrlLoading: true,
        ),
      ),
      shouldOverrideUrlLoading: (controller, action) async{
        _onNavigationRequest(action.request);
        return NavigationActionPolicy.ALLOW;
      },
      onWebViewCreated: (controller){
        _controller = controller;
      },
    );

    if (_config.navigatorKey.currentState == null) {
      throw Exception(
        'Could not push new route using provided navigatorKey, Because '
        'NavigatorState returned from provided navigatorKey is null. Please Make sure '
        'provided navigatorKey is passed to WidgetApp. This can also happen if at the time of this method call '
        'WidgetApp is not part of the flutter widget tree',
      );
    }

    await _config.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: _config.appBar,
          body: WillPopScope(
            onWillPop: () async {
              if (await _controller.canGoBack()) {
                await _controller.goBack();
                return false;
              }
              return true;
            },
            child: SafeArea(
              child: Stack(
                children: [_config.loader, webView],
              ),
            ),
          ),
        ),
      ),
    );
    return _code;
  }

  Future<void> _onNavigationRequest(
      URLRequest request) async {
    try {
      var uri = request.url;
      if(uri == null) return;

      if (uri.queryParameters['error'] != null) {
        _config.navigatorKey.currentState!.pop();
      }

      var checkHost = uri.host == _redirectUriHost;

      if (uri.queryParameters['code'] != null && checkHost) {
        _code = uri.queryParameters['code'];
        List<Cookie> cookies = await _manager.getCookies(url: Uri.parse("https://login.microsoftonline.com"));
        List<Map<String,dynamic>> cookieJson = cookies.map((e) => e.toJson()).toList();
        await _authStorage.saveCookies(cookieJson);
        _config.navigatorKey.currentState!.pop();
      }
    } catch (_) {}
  }

  Future<void> clearCookies() async {
    await CookieManager.instance().deleteAllCookies();
  }

  String _constructUrlParams() => _mapToQueryParams(
      _authorizationRequest.parameters, _config.customParameters);

  String _mapToQueryParams(
      Map<String, String> params, Map<String, String> customParams) {
    final queryParams = <String>[];

    params.forEach((String key, String value) =>
        queryParams.add('$key=${Uri.encodeQueryComponent(value)}'));

    customParams.forEach((String key, String value) =>
        queryParams.add('$key=${Uri.encodeQueryComponent(value)}'));
    return queryParams.join('&');
  }
}
