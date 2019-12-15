import 'package:retriever/retriever.dart';
import 'package:http/http.dart';
import 'package:async/async.dart';

main() async {
  print("hej");
  var i = 0;
  final retriever = new Retriever<Uri, String>((url, retriever) {
    fetch() async {
      String body;
      try {
        print('${i++} fetching $url');
        body = await Future.any(
            [Future.delayed(Duration(seconds: 2), () async => ""), read(url)]);
      } catch (e) {
        print("error $e");
      } finally {}
      RegExp(r'<a href="(http[^"]*)"').allMatches(body ?? '').forEach((l) {
        print("$url ${Uri.parse(l[1])}");
        retriever.enqueue(Uri.parse(l[1]));
      });
      return body;
    }

    return CancelableOperation.fromFuture(fetch());
  }, maxConcurrentOperations: 30);

  retriever
      .enqueue(Uri.parse('https://github.com/gskinnerTeam/flutter_vignettes'));
  print("farvel");
  await Future.delayed(Duration(days: 1));
}
