# oauth_dio

A customizable oauth client with token storage and interceptors for [dio](https://pub.dev/packages/dio).

## Getting Started

Instantiate a new OAuth Client:

```dart
// myclient.dart
import 'package:oauth_dio/oauth_dio.dart';

final oauth = OAuth(
      tokenUrl: '<YOUR TOKEN URL>',
      clientId: '<YOUR CLIENT ID>',
      clientSecret: '<YOUR SECRET>');
```

Obtaining an access token using username and password:

```dart
OAuthToken token = oauth.requestToken(
  PasswordGrant(
    username: '<YOUR USERNAME>',
    password: '<YOUR PASSWORD>'
  )
).then((token) {
    print(token.accessToken);
});
```

Updating access token using a refresh token:

```dart
OAuthToken token = oauth.requestToken(
  RefreshTokenGrant(
    refreshToken: '<YOUR REFRESH TOKEN>'
  )
).then((token) {
    print(token.accessToken);
});
```

## Configuring Dio to send access tokens:
Instantiate a new OAuth Client with  a permanent storage, by default oauth is configured with memory storage.

In this example we will use the [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) plugin to store the token on the device's keychain.

```dart
// myclient.dart
import 'package:oauth_dio/oauth_dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class OAuthSecureStorage extends OAuthStorage {
  final FlutterSecureStorage storage;
  final accessTokenKey = 'accessToken';
  final refreshTokenKey = 'refreshToken';

  @override
  Future<OAuthToken> fetch() async {
    return OAuthToken(
        accessToken: await storage.read(key: accessTokenKey),
        refreshToken: await storage.read(key: refreshTokenKey);
    )
  }

  @override
  Future<OAuthToken> save(OAuthToken token) async {
    await storage.write(key: accessTokenKey, value: token.acessToken);
    await storage.write(key: refreshTokenKey, value: token.refreshToken);
    return token;
  }

  Future<void> clear() async {
    await storage.delete(key: accessTokenKey);
    await storage.delete(key: refreshTokenKey);
  }
}

final oauth = OAuth(
    tokenUrl: '<YOUR TOKEN URL>',
    clientId: '<YOUR CLIENT ID>',
    clientSecret: '<YOUR SECRET>',
    storage: OAuthSecureStorage()
);

final authenticadedDio = Dio()
authenticadedDio.interceptors.add(BearerInterceptor(oauth: oauth))


authenticadedDio.get('/my/protected/resource').then((response) {
    print(response.data);
})
```

## Custom grant types

Use the abstract class OAuthGrantType to implement a custom grant type.

```dart
import 'package:oauth_dio/oauth_dio.dart';

class TicketGrant extends OAuthGrantType {
  String accessToken;

  TicketGrant({
    this.accessToken
  })

  @override
  RequestOptions handle (RequestOptions request) {
    request.data = "grant_type=ticket&access_token=$accessToken";
    return request;
  }
}

// Request token using ticket grant
oauth.requestToken(
  TicketGrant(
    accessToken: 'foobar'
  )
)

```

## Feedback
Please feel free to [give me any feedback](https://github.com/salomaosnff/oauth_dio/issues) helping support this package!
