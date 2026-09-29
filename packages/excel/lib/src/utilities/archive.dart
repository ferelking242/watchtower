part of excel;

Archive _cloneArchive(
  Archive archive,
  Map<String, ArchiveFile> _archiveFiles, {
  String? excludedFile,
}) {
  var clone = Archive();
  archive.files.forEach((file) {
    if (file.isFile) {
      if (excludedFile != null &&
          file.name.toLowerCase() == excludedFile.toLowerCase()) {
        return;
      }
      ArchiveFile copy;
      if (_archiveFiles.containsKey(file.name)) {
        copy = _archiveFiles[file.name]!;
      } else {
        var content = file.content as Uint8List;
        // archive 4.x removed the `compress` setter; ArchiveFile auto-selects
        // compression at write time based on the file content.
        copy = ArchiveFile(file.name, content.length, content);
      }
      clone.addFile(copy);
    }
  });
  return clone;
}
