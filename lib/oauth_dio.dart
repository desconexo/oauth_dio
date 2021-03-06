library oauth_dio;

import 'dart:convert';

import 'package:dio/dio.dart';

typedef OAuthToken OAuthTokenExtractor(Response response);
typedef Future<bool> OAuthTokenValidator(OAuthToken token);

/// Interceptor to send the bearer access token and update the access token when needed
class BearerInterceptor extends Interceptor {
  OAuth oauth;

  BearerInterceptor(this.oauth);

  /// Add Bearer token to Authorization Header
  @override
  Future onRequest(RequestOptions options) async {
    final token = await oauth.fetchOrRefreshAccessToken();
    if (token != null) {
      options.headers.addAll({"Authorization": "Bearer ${token.accessToken}"});
    }
    return options;
  }
}

/// Use to implement a custom grantType
abstract class OAuthGrantType {
  /// handleRefreshToken is only needed in case you're using refreshGrantType to personalize you're own data in refreshAccessToken
  RequestOptions handle(RequestOptions request, {String handleRefreshToken});
}

/// Obtain an access token using a username and password
class PasswordGrant extends OAuthGrantType {
  String username;
  String password;
  List<String> scope = [];

  PasswordGrant({this.username, this.password, this.scope});

  /// Prepare Request
  @override
  RequestOptions handle(RequestOptions request, {String handleRefreshToken}) {
    request.data =
        "grant_type=password&username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}&scope=${this.scope.join(' ')}";
    return request;
  }
}

/// Obtain an access token using an refresh token
class RefreshTokenGrant extends OAuthGrantType {
  String refreshToken;

  RefreshTokenGrant({this.refreshToken});

  /// Prepare Request
  @override
  RequestOptions handle(RequestOptions request, {String handleRefreshToken}) {
    request.data = "grant_type=refresh_token&refresh_token=$refreshToken";
    return request;
  }
}

/// Use to implement custom token storage
abstract class OAuthStorage {
  /// Read token
  Future<OAuthToken> fetch();

  /// Save Token
  Future<OAuthToken> save(OAuthToken token);

  /// Clear token
  Future<void> clear();
}

/// Save Token in Memory
class OAuthMemoryStorage extends OAuthStorage {
  OAuthToken _token;

  /// Read
  @override
  Future<OAuthToken> fetch() async {
    return _token;
  }

  /// Save
  @override
  Future<OAuthToken> save(OAuthToken token) async {
    return _token = token;
  }

  /// Clear
  Future<void> clear() async {
    _token = null;
  }
}

/// Token
class OAuthToken {
  String accessToken;
  String refreshToken;

  OAuthToken({this.accessToken, this.refreshToken});
}

/// Encode String To Base64
Codec<String, String> stringToBase64 = utf8.fuse(base64);

/// OAuth Client
/// You need to use refreshGrantType only to personalize the data you send to your back-end
class OAuth {
  Dio dio;
  String tokenUrl;
  String clientId;
  String clientSecret;
  OAuthStorage storage;
  OAuthTokenExtractor extractor;
  OAuthTokenValidator validator;
  OAuthGrantType refreshGrantType;

  OAuth({
    this.tokenUrl,
    this.clientId,
    this.clientSecret,
    this.extractor,
    this.dio,
    this.storage,
    this.validator,
    this.refreshGrantType,
  }) {
    dio = dio ?? Dio();
    storage = storage ?? OAuthMemoryStorage();
    extractor = extractor ??
        (res) => OAuthToken(
            accessToken: res.data['access_token'],
            refreshToken: res.data['refresh_token']);
    validator = validator ?? (token) => Future.value(true);
  }

  Future<OAuthToken> requestTokenAndSave(OAuthGrantType grantType,
      {String refreshToken}) async {
    return requestToken(grantType, refreshToken: refreshToken)
        .then((token) => storage.save(token));
  }

  /// Request a new Access Token using a strategy
  Future<OAuthToken> requestToken(OAuthGrantType grantType,
      {String refreshToken}) {
    final request = grantType.handle(
      RequestOptions(
          method: 'POST',
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization":
                "Basic ${stringToBase64.encode('$clientId:$clientSecret')}"
          }),
      handleRefreshToken: refreshToken,
    );

    return dio
        .request(tokenUrl, data: request.data, options: request)
        .then((res) => extractor(res));
  }

  /// return current access token or refresh
  Future<OAuthToken> fetchOrRefreshAccessToken() async {
    OAuthToken token = await storage.fetch();

    if (token == null) {
      return null;
    }

    if (await this.validator(token)) return token;

    return this.refreshAccessToken();
  }

  /// Refresh Access Token
  Future<OAuthToken> refreshAccessToken() async {
    OAuthToken token = await storage.fetch();

    if (refreshGrantType == null) {
      return this.requestTokenAndSave(
          RefreshTokenGrant(refreshToken: token.refreshToken));
    } else {
      return this.requestTokenAndSave(refreshGrantType,
          refreshToken: token.refreshToken);
    }
  }
}
