// Fake content source for M1/M2 (CONTRACTS 8.1 `data/dev/`): reads the
// bundled copies of backend/data/samples and docs/examples in assets/dev/.
// S12 replaces it with the dio API client behind the same interface.
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';

import '../repositories/content_source.dart';

class DevContentSource implements ContentSource {
  DevContentSource(this.bundle);

  final AssetBundle bundle;

  @override
  Future<String> catalogueJson() =>
      bundle.loadString('assets/dev/catalogue.json');

  @override
  Future<String> titleJson(String id) async {
    // Only slugs: never let an id build an arbitrary asset path.
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(id)) {
      throw TitleNotFound(id);
    }
    try {
      return await bundle.loadString('assets/dev/$id.json');
    } on FlutterError {
      throw TitleNotFound(id);
    }
  }
}
