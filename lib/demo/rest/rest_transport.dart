import 'dart:convert';
import 'dart:io';

class RestWireResponse {
  const RestWireResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

/// Ін'єкція транспорту дозволяє тестувати відповіді без мережі.
abstract interface class RestTransport {
  Future<RestWireResponse> send(String method, Uri uri, {String? body});
  void close();
}

class IoRestTransport implements RestTransport {
  IoRestTransport({HttpClient? client}) : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 5);
  }
  final HttpClient _client;
  @override
  Future<RestWireResponse> send(String method, Uri uri, {String? body}) async {
    final request = await _client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(body));
    }
    final response = await request.close();
    final data = await response.transform(utf8.decoder).join();
    return RestWireResponse(response.statusCode, data);
  }

  @override
  void close() => _client.close(force: true);
}
