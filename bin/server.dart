import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

final yt = YoutubeExplode();

Router createRouter() {
  final router = Router();

  // Endpoint: búsqueda de videos
  router.get('/search', (Request req) async {
    final query = req.url.queryParameters['q'] ?? '';
    if (query.isEmpty) return Response(400, body: 'Falta parámetro "q"');

    try {
      final videos = await yt.search.getVideos(query);
      final results = videos.map((v) => {
        'id': v.id.value,
        'title': v.title ?? 'Sin título',
        'author': v.author ?? 'Autor desconocido',
        'duration': v.duration?.inSeconds ?? 0,
      }).toList();

      return Response.ok(
        results.toString(),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        },
      );
    } catch (e, st) {
      stderr.writeln('Error en /search: $e\n$st');
      return Response(500, body: 'Error interno al buscar videos');
    }
  });

  // Endpoint: stream de audio directamente
  router.get('/stream', (Request req) async {
    final id = req.url.queryParameters['id'];
    if (id == null || id.isEmpty) {
      return Response(400,
          body: 'Falta parámetro "id"',
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
          });
    }

    try {
      final manifest = await yt.videos.streams.getManifest(id);
      final audioStreams = manifest.audioOnly.toList();

      if (audioStreams.isEmpty) {
        return Response(404, body: 'No se encontraron streams de audio');
      }

      // Tomamos el de mayor bitrate
      final audioStreamInfo = audioStreams.first;
      final audioStream = await yt.videos.streams.get(audioStreamInfo);

      // Devuelve los bytes de audio directamente
      return Response.ok(
        audioStream,
        headers: {
          'Content-Type': 'audio/mpeg', // o 'audio/webm' según audioStreamInfo.container
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
        },
      );
    } catch (e, st) {
      print('Error en /stream: $e\n$st');
      return Response.internalServerError(body: 'Error al obtener el audio');
    }
  });

  return router;
}

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
      }))
      .addHandler(createRouter());

  try {
    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    print('Servidor corriendo en http://${server.address.host}:${server.port}');

    ProcessSignal.sigint.watch().listen((_) async {
      print('Recibida señal SIGINT. Cerrando servidor...');
      await server.close();
      await yt.close();
      exit(0);
    });

    ProcessSignal.sigterm.watch().listen((_) async {
      print('Recibida señal SIGTERM. Cerrando servidor...');
      await server.close();
      await yt.close();
      exit(0);
    });
  } catch (e, st) {
    print('Error al iniciar el servidor: $e\n$st');
    exit(1);
  }
}
