import 'dart:io';

/// Small backend proxy for the Flutter clients.
///
/// Configure the upstream URL, including its access key, only in the server
/// environment with `-DMOBILIBUS_UPSTREAM_URL=...`. Do not pass that value to
/// a Flutter build.
const _upstreamUrl = String.fromEnvironment('MOBILIBUS_UPSTREAM_URL');
const _allowedOrigin = String.fromEnvironment('MOBILIBUS_ALLOWED_ORIGIN');
Future<void> main(List<String> arguments) async {
  final upstreamUri = Uri.tryParse(_upstreamUrl);
  if (upstreamUri == null ||
      !upstreamUri.hasScheme ||
      (upstreamUri.scheme != 'http' && upstreamUri.scheme != 'https')) {
    stderr.writeln(
      'MOBILIBUS_UPSTREAM_URL must be an absolute HTTP(S) URL. '
      'Configure it only on the proxy server.',
    );
    exitCode = 64;
    return;
  }
  final port = _portFrom(arguments);
  HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } on SocketException {
    stderr.writeln(
      'Port $port is already in use. A Mobilibus proxy may already be running. '
      'Stop it first, or use --port with a different value.',
    );
    return;
  }
  final client = HttpClient();
  stdout.writeln('Mobilibus proxy listening at http://localhost:$port');

  await for (final request in server) {
    if (!_isAllowedOrigin(request.headers.value(HttpHeaders.originHeader))) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.write('Origin is not allowed.');
      await request.response.close();
      continue;
    }
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
      final upstreamRequest = await client.getUrl(upstreamUri);
      final upstreamResponse = await upstreamRequest.close();
      request.response.statusCode = upstreamResponse.statusCode;
      final contentType = upstreamResponse.headers.contentType;
      if (contentType != null) request.response.headers.contentType = contentType;
      await request.response.addStream(upstreamResponse);
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.badGateway;
      request.response.write('Could not reach the Mobilibus feed.');
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
    ..set(HttpHeaders.accessControlAllowOriginHeader, _allowedOrigin)
    ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, OPTIONS')
    ..set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type');
}

bool _isAllowedOrigin(String? origin) {
  // Requests without an Origin header are native clients or same-origin calls.
  if (origin == null) return true;
  return _allowedOrigin.isNotEmpty && origin == _allowedOrigin;
}
