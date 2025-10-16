import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
<<<<<<< HEAD

final yt = YoutubeExplode();

Response _cors(Response response) => response.change(headers: {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
});

Future<Response> _optionsHandler(Request request) async =>
    Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type',
    });

void main() async {
  final app = Router();

  // Ruta de búsqueda
  app.get('/search', (Request req) async {
    final query = req.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return _cors(Response(400, body: 'Missing query parameter q'));
    }

    final searchResults = await yt.search.search(query);
    final List<Map<String, dynamic>> videos = [];

    await for (final result in searchResults) {
      if (result is Video) {
        videos.add({
          'id': result.id.value,
          'title': result.title,
          'author': result.author,
          'duration': result.duration?.inSeconds ?? 0,
        });
      }
      if (videos.length >= 10) break;
    }

    return _cors(Response.ok(jsonEncode(videos),
        headers: {'Content-Type': 'application/json'}));
  });

  // Ruta para obtener el stream de audio
  app.get('/audio', (Request req) async {
    final id = req.url.queryParameters['id'];
    if (id == null || id.isEmpty) {
      return _cors(Response(400, body: 'Missing video id'));
    }

    try {
      final manifest = await yt.videos.streamsClient.getManifest(id);
      final audio = manifest.audioOnly.withHighestBitrate();

      if (audio == null) {
        return _cors(Response(404, body: 'No audio stream found'));
      }

      // Redirige directamente al stream (el navegador lo puede reproducir)
      return _cors(Response.found(audio.url.toString()));
    } catch (e) {
      return _cors(Response.internalServerError(body: 'Error: $e'));
    }
  });

  // CORS preflight
  app.options('/<ignored|.*>', _optionsHandler);

  // Iniciar servidor
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(app);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('✅ Server listening on port ${server.port}');
=======

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
>>>>>>> 3062428fa2089a3297374eb6d8ce149d5438850e
}
