import 'package:retriever/retriever.dart';
import 'package:http/http.dart';

  final retriever = new PooledRetriever<Uri, String>();

Future<String> getUrl(Uri url) async {
  String body;
  try {
  body = (await get(url)).body;
  } catch (e) {
    print("error $e");
  } finally {}
  RegExp(r'<a href="(.[^"]*)"').allMatches(body ?? '').forEach((l) {
  //  print("$url ${l[1]}");
    try {
    enqueue(Uri.parse(l[1]));
    } finally {}
  });
  return body;
}

enqueue(Uri uri) {
    final task = Task<Uri, String>(
     uri,
      getUrl,
      (url) {},
      1);
      retriever.enqueue(task);
}

main() {
  print("hej");

  enqueue(Uri.parse('https://github.com/gskinnerTeam/flutter_vignettes'));
  print("farvel");
}
