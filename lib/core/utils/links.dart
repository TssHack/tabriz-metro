import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an external app/browser; returns false on failure.
Future<bool> openExternal(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } on Object {
    return false;
  }
}

/// Walking directions to a point in the user's map app.
Future<bool> openWalkingDirections(double lat, double lng, {String? label}) {
  final url = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$lat,$lng',
    'travelmode': 'walking',
  });
  return openExternal(url.toString());
}
