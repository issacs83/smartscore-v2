/// Stub for dart:io types on web platform
class Directory {
  final String path;
  Directory(this.path);
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
  Future<void> delete({bool recursive = false}) async {}
}

class File {
  final String path;
  File(this.path);
  Future<List<int>> readAsBytes() async => [];
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<bool> exists() async => false;
  Directory get parent => Directory(path.substring(0, path.lastIndexOf('/')));
}
