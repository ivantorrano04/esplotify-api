import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final yt = YoutubeExplode();

// Middleware CORS
Handler corsMiddleware(Handler handler) {
  return (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      });
    }

    final response = await handler(request);
    return response.change(headers: {
      ...response.headers,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
  };
}

Router createRouter() {
  final router = Router();

  // Ruta de prueba para Cloud Run (healthcheck)
  router.get('/', (Request req) {
    return Response.ok('✅ Esplotify API corriendo correctamente');
  });

  // Búsqueda de videos
  router.get('/search', (Request req) async {
    final query = req.url.queryParameters['q'] ?? '';
    if (query.isEmpty) {
      return Response(400, body: 'Falta parámetro "q"');
    }

    try {
      final videos = await yt.search.getVideos(query);
      final results = videos.map((v) => {
        'id': v.id.value,
        'title': v.title,
        'author': v.author,
        'duration': v.duration?.inSeconds ?? 0,
      }).toList();

      return Response.ok(
        jsonEncode(results),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      stderr.writeln('🔍 Error en /search: $e\n$stack');
      return Response.internalServerError(body: 'Error al buscar videos');
    }
  });

  // Stream de audio
  router.get('/stream', (Request req) async {
    final id = req.url.queryParameters['id'];
    if (id == null || id.isEmpty) {
      return Response(400, body: 'Falta parámetro "id"');
    }

    try {
      final manifest = await yt.videos.streams.getManifest(id);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      if (audioStream == null) {
        return Response(404, body: 'No se encontró stream de audio');
      }

      return Response.ok(
        jsonEncode({'url': audioStream.url.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      stderr.writeln('🔊 Error en /stream: $e\n$stack');
      return Response.internalServerError(body: 'Error al obtener stream de audio');
    }
  });

  return router;
}

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(corsMiddleware(createRouter()));

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('🚀 Servidor escuchando en puerto ${server.port}');
  print('🌍 URL: http://localhost:${server.port}');
}
