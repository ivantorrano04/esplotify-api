import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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

  // --- Buscar canciones ---
  app.get('/search', (Request req) async {
    final query = req.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return _cors(Response(400, body: 'Missing query parameter q'));
    }

    final searchResults = await yt.search.search(query);
    final List<Map<String, dynamic>> videos = [];

    for (final result in searchResults) {
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

  // --- Obtener la URL del stream de audio ---
router.get('/audio', (Request req) async {
  final id = req.url.queryParameters['id'];
  if (id == null) {
    return Response.badRequest(body: 'Missing id');
  }

  try {
    final manifest = await yt.videos.streamsClient.getManifest(id);
    final audio = manifest.audioOnly.withHighestBitrate();
    return Response.ok(jsonEncode({'url': audio.url.toString()}),
        headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(body: e.toString());
  }
});


  // --- CORS preflight ---
  app.options('/<ignored|.*>', _optionsHandler);

  // --- Arranque ---
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(app);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('✅ Server running on port ${server.port}');
}
