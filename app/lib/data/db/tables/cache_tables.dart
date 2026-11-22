// Content cache (CONTRACTS 5.1). Not personal: "Clear my data" keeps it so
// the app still works offline.
import 'package:drift/drift.dart';

/// Whole JSON payloads by key: `catalogue`, `credits`, `otd:MM-DD`.
@DataClassName('CachedDocRow')
class CachedDocs extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// One TitleDetail JSON per opened title. Never evicted.
@DataClassName('CachedTitleRow')
class CachedTitles extends Table {
  TextColumn get titleId => text()();
  TextColumn get payload => text()();
  IntColumn get contentVersion => integer()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {titleId};
}
