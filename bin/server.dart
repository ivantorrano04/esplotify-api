import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:mime/mime.dart';

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

    try {
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

      return _cors(Response.ok(
        jsonEncode(videos),
        headers: {'Content-Type': 'application/json'},
      ));
    } catch (e) {
      return _cors(Response.internalServerError(body: 'Search failed: $e'));
    }
  });

  // --- Proxy de audio: transmite el stream correctamente ---
  app.get('/audio', (Request req) async {
    final id = req.url.queryParameters['id'];
    if (id == null) {
      return _cors(Response.badRequest(body: 'Missing id'));
    }

    try {
      final manifest = await yt.videos.streamsClient.getManifest(id);
      final audioStream = manifest.audioOnly.withHighestBitrate();

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(audioStream.url.toString()));
      request.headers.add(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      );
      final response = await request.close();

      // Determinar el tipo MIME
      final ext = audioStream.container.name.toLowerCase();
      String? mimeType = lookupMimeType('file.$ext');
      if (mimeType == null) {
        mimeType = ext == 'webm' ? 'audio/webm' : 'audio/mp4';
      }

      return _cors(Response(
        200,
        body: response.cast<List<int>>(), // <- Stream de bytes correcto
        headers: {
          'Content-Type': mimeType,
          'Content-Length': response.contentLength.toString(),
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ));
    } catch (e, stack) {
      print('❌ Error en /audio?id=$id: $e\n$stack');
      return _cors(Response.internalServerError(body: 'Audio stream unavailable'));
    }
  });

  // --- Manejo de CORS preflight para todas las rutas ---
  app.options('/<ignored|.*>', _optionsHandler);

  // --- Iniciar servidor ---
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(app);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('✅ Server running on port ${server.port}');
}
