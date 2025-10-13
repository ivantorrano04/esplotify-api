import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

final yt = YoutubeExplode();

Router createRouter() {
  final router = Router();

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
        'title': v.title ?? 'Sin título',
        'author': v.author ?? 'Autor desconocido',
        'duration': v.duration?.inSeconds ?? 0,
      }).toList();

      return Response.ok(
        jsonEncode(results),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      // Opcional: imprime el error en los logs del contenedor
      stderr.writeln('Error en /search: $e\n$stackTrace');
      return Response(500, body: 'Error interno al buscar videos');
    }
  });

  // Obtener URL de stream de audio
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

      final streamUrl = audioStream.url.toString();

      return Response.ok(
        jsonEncode({'url': streamUrl}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stackTrace) {
      stderr.writeln('Error en /stream: $e\n$stackTrace');
      return Response(500, body: 'Error al obtener el stream de audio');
    }
  });

  return router;
}

void main() async {
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders()) // <-- Agrega esto
      .addHandler(createRouter());

  final server = await shelf_io.serve(handler, '0.0.0.0', 8080);
  print('Servidor corriendo en http://localhost:8080');
}