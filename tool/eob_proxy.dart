import 'dart:io';

const _upstreamUrl =
    'http://realtime4.mobilibus.com/web/4ch6j/vehicle-positions?accesskey=982a57efd77a9462bf1665696fb25984';

/// Development-only CORS proxy for the Flutter Web app.
///
/// The upstream endpoint is GTFS-Realtime Protocol Buffers and does not send
/// Access-Control-Allow-Origin. Keep the access key server-side for production.
Future<void> main(List<String> arguments) async {
  final port = _portFrom(arguments);
  HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } on SocketException {
    stderr.writeln(
      'Port $port is already in use. An EOB proxy may already be running. '
      'Stop it first, or use --port with a different value.',
    );
    return;
  }
  final client = HttpClient();
  stdout.writeln('EOB proxy listening at http://localhost:$port');

  await for (final request in server) {
    _addCorsHeaders(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      continue;
    }
    if (request.method != 'GET' || request.uri.path != '/vehicle-positions') {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Use GET /vehicle-positions');
      await request.response.close();
      continue;
    }

    try {
      final upstreamRequest = await client.getUrl(Uri.parse(_upstreamUrl));
      final upstreamResponse = await upstreamRequest.close();
      request.response.statusCode = upstreamResponse.statusCode;
      final contentType = upstreamResponse.headers.contentType;
      if (contentType != null) request.response.headers.contentType = contentType;
      await request.response.addStream(upstreamResponse);
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.badGateway;
      request.response.write('Could not reach the upstream feed.');
      await request.response.close();
    }
  }
}

int _portFrom(List<String> arguments) {
  if (arguments.length == 2 && arguments.first == '--port') {
    final port = int.tryParse(arguments.last);
    if (port != null && port > 0 && port <= 65535) return port;
  }
  return 8080;
}

void _addCorsHeaders(HttpResponse response) {
  response.headers
    ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
    ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, OPTIONS')
    ..set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type');
}
