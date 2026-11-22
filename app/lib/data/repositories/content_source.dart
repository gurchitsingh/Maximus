/// Where catalogue and title JSON come from: bundled dev assets now (S6),
/// the /v1 API from S12.
abstract interface class ContentSource {
  /// GET /v1/catalogue body.
  Future<String> catalogueJson();

  /// GET /v1/titles/{id} body. Throws [TitleNotFound].
  Future<String> titleJson(String id);
}

class TitleNotFound implements Exception {
  const TitleNotFound(this.id);
  final String id;

  @override
  String toString() => 'TitleNotFound($id)';
}
