import 'package:mealmate/demo/rest/rest_transport.dart';

class MockRestTransport implements RestTransport {
  MockRestTransport(this.handler);
  final Future<RestWireResponse> Function(String, Uri, String?) handler;
  int calls = 0;
  bool closed = false;
  @override
  Future<RestWireResponse> send(String method, Uri uri, {String? body}) {
    calls++;
    return handler(method, uri, body);
  }

  @override
  void close() => closed = true;
}
