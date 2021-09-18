import 'package:firebase/firebase.dart';

export 'package:firebase_database/firebase_database.dart'
    hide FirebaseDatabase, Query;

class FirebaseDatabase {
  static FirebaseDatabase get instance => FirebaseDatabase._();

  FirebaseDatabase._();

  String? get databaseURL => database().app.options.databaseURL;

  Future<void> goOffline() async {
    return database().goOffline();
  }

  Future<void> goOnline() async {
    return database().goOnline();
  }

  FirebaseDatabase reference() {
    return this;
  }

  DatabaseReference child(String path) {
    return database().ref(path);
  }
}
