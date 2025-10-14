import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final router = Router();

  // Endpoint para buscar videos por query
  router.get('/search', (Request request) async {
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return Response.badRequest(body: 'Query parameter "q" is required.');
    }

    final yt = YoutubeExplode();
    try {
      // Busca los 10 primeros resultados
      final results = await yt.search.search(query).take(10).toList();

      final videos = results
          .whereType<Video>()
          .map((video) => {
                'id': video.id.value,
                'title': video.title,
                'author': video.author,
                'duration': video.duration?.inSeconds ?? 0
              })
          .toList();

      return Response.ok(jsonEncode(videos),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error: $e');
    } finally {
      yt.close();
    }
  });

  // Endpoint para obtener la URL de audio de un video
  router.get('/audio', (Request request) async {
    final videoId = request.url.queryParameters['id'];
    if (videoId == null || videoId.isEmpty) {
      return Response.badRequest(body: 'Query parameter "id" is required.');
    }

    final yt = YoutubeExplode();
    try {
      // Obtiene el manifiesto de streams usando clientes compatibles
      final manifest = await yt.videos.streams.getManifest(videoId,
          ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr]);

      // Selecciona el primer stream de audio disponible
      final audioStream = manifest.audioOnly.first;
      final audioUrl = audioStream.url.toString();

      return Response.ok(jsonEncode({'audioUrl': audioUrl}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error fetching audio: $e');
    } finally {
      yt.close();
    }
  });

  // Middleware para log de requests
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router);

  // Escucha en el puerto que Cloud Run asigna
  final port =
      int.tryParse(const String.fromEnvironment('PORT', defaultValue: '8080')) ??
          8080;
  final server = await shelf_io.serve(handler, '0.0.0.0', port);
  print('Server listening on port ${server.port}');
}
