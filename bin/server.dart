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
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        },
      );
    } catch (e, stackTrace) {
      stderr.writeln('Error en /search: $e\n$stackTrace');
      return Response(500, body: 'Error interno al buscar videos');
    }
  });

  // Obtener URL de stream de audio
  router.get('/stream', (Request req) async {
    final id = req.url.queryParameters['id'];
    if (id == null || id.isEmpty) {
      return Response(400, 
        body: jsonEncode({
          'error': 'Falta parámetro "id"',
          'status': 400
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        }
      );
    }

    try {
      print('Obteniendo manifest para video ID: $id');
      final manifest = await yt.videos.streams.getManifest(id);
      
      // Obtener todos los streams de audio disponibles
      final audioStreams = manifest.audioOnly.toList();
      
      if (audioStreams.isEmpty) {
        return Response(404,
          body: jsonEncode({
            'error': 'No se encontraron streams de audio',
            'status': 404,
            'videoId': id
          }),
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
          }
        );
      }

      // Ordenar por bitrate y tomar el más alto
      audioStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final audioStream = audioStreams.first;
      
      print('Stream encontrado: ${audioStream.bitrate} bps, codec: ${audioStream.codec}');
      final streamUrl = audioStream.url.toString();

      return Response.ok(
        jsonEncode({
          'url': streamUrl,
          'bitrate': audioStream.bitrate.bitsPerSecond,
          'codec': audioStream.codec.name,
          'container': audioStream.container.name,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        },
      );
    } catch (e, stackTrace) {
      print('Error detallado: $e\n$stackTrace');
      return Response(500,
        body: jsonEncode({
          'error': 'Error al obtener el stream de audio',
          'message': e.toString(),
          'status': 500,
          'videoId': id
        }),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
        }
      );
    }
  });

  return router;
}

void main() async {
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
      }))
      .addHandler(createRouter());

  final server = await shelf_io.serve(handler, '0.0.0.0', 8080);
  print('Servidor corriendo en http://localhost:8080');
}