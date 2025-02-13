import 'dart:io';
import 'dart:math';
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// The recognised file class to be used for this package
class CloudinaryFile {
  /// The [ByteData] file to be uploaded
  final ByteData? byteData;

  /// The bytes data to be uploaded
  final List<int>? bytesData;

  /// The path of the [File] to be uploaded
  final String? filePath;

  /// The file public id which will be used to name the file
  final String? publicId;

  /// The file name/path
  final String identifier;

  /// An optional folder name where the uploaded asset will be stored.
  /// The public ID will contain the full path of the uploaded asset,
  /// including the folder name.
  final String? folder;

  /// External url
  final String? url;

  /// The cloudinary resource type to be uploaded
  /// see [CloudinaryResourceType.Auto] - default,
  /// [CloudinaryResourceType.Image],
  /// [CloudinaryResourceType.Video],
  /// [CloudinaryResourceType.Raw],
  final CloudinaryResourceType resourceType;

  /// File tags
  final List<String>? tags;

  /// A pipe-separated list of the key-value pairs of contextual metadata to
  /// attach to an uploaded asset.
  ///
  /// Eg: {'alt': 'My image', 'caption': 'Profile image'}
  final Map<String, dynamic>? context;

  /// Determine if initialized from [CloudinaryFile.fromUrl]
  bool get fromExternalUrl => url != null;

  int get fileSize {
    if (byteData != null) {
      return byteData!.lengthInBytes;
    } else if (bytesData != null) {
      return bytesData!.length;
    } else if (filePath != null) {
      return File(filePath!).lengthSync();
    } else {
      return 0;
    }
  }

  /// [CloudinaryFile] instance
  const CloudinaryFile._({
    this.resourceType: CloudinaryResourceType.Auto,
    this.byteData,
    this.bytesData,
    this.filePath,
    this.publicId,
    required this.identifier,
    this.url,
    this.tags,
    this.folder,
    this.context,
  });

  /// Instantiate [CloudinaryFile] from future [ByteData]
  static Future<CloudinaryFile> fromFutureByteData(
    Future<ByteData> byteData, {
    required String identifier,
    String? publicId,
    CloudinaryResourceType resourceType: CloudinaryResourceType.Auto,
    List<String>? tags,
  }) async =>
      CloudinaryFile.fromByteData(
        await byteData,
        publicId: publicId,
        identifier: identifier,
        resourceType: resourceType,
        tags: tags,
      );

  /// Instantiate [CloudinaryFile] from [ByteData]
  factory CloudinaryFile.fromByteData(
    ByteData byteData, {
    required String identifier,
    String? publicId,
    CloudinaryResourceType resourceType: CloudinaryResourceType.Auto,
    List<String>? tags,
    String? folder,
    Map<String, dynamic>? context,
  }) {
    return CloudinaryFile._(
      byteData: byteData,
      publicId: publicId,
      identifier: identifier,
      resourceType: resourceType,
      tags: tags,
      folder: folder,
      context: context,
    );
  }

  /// Instantiate [CloudinaryFile] from [ByteData]
  factory CloudinaryFile.fromBytesData(
    List<int> bytesData, {
    required String identifier,
    String? publicId,
    CloudinaryResourceType resourceType: CloudinaryResourceType.Auto,
    List<String>? tags,
    String? folder,
    Map<String, dynamic>? context,
  }) {
    return CloudinaryFile._(
      bytesData: bytesData,
      publicId: publicId,
      identifier: identifier,
      resourceType: resourceType,
      tags: tags,
      folder: folder,
      context: context,
    );
  }

  /// Instantiate [CloudinaryFile] from [File] path
  factory CloudinaryFile.fromFile(
    String path, {
    String? publicId,
    String? identifier,
    CloudinaryResourceType resourceType: CloudinaryResourceType.Auto,
    List<String>? tags,
    String? folder,
    Map<String, dynamic>? context,
  }) {
    return CloudinaryFile._(
      filePath: path,
      publicId: publicId,
      identifier: identifier ??= path.split('/').last,
      resourceType: resourceType,
      tags: tags,
      folder: folder,
      context: context,
    );
  }

  /// Instantiate [CloudinaryFile] from an external url
  factory CloudinaryFile.fromUrl(
    String url, {
    CloudinaryResourceType resourceType: CloudinaryResourceType.Auto,
    List<String>? tags,
    String? folder,
    Map<String, dynamic>? context,
  }) {
    return CloudinaryFile._(
      url: url,
      identifier: url,
      resourceType: resourceType,
      folder: folder,
      context: context,
    );
  }

  /// Convert [CloudinaryFile] to [MultipartFile]
  Future<MultipartFile> toMultipartFile([String fieldName = 'file']) async {
    assert(
      !fromExternalUrl,
      'toMultipartFile() not available when uploading from external urls',
    );

    if (byteData != null) {
      return MultipartFile.fromBytes(
        byteData?.buffer.asUint8List() ?? [],
        filename: identifier,
      );
    }

    if (bytesData != null) {
      return MultipartFile.fromBytes(
        bytesData!,
        filename: identifier,
      );
    }

    return MultipartFile.fromFile(
      filePath!,
      filename: identifier,
    );
  }

  /// Convert to multipart with chunked upload
  MultipartFile toMultipartFileChunked(
    int start,
    int end,
  ) {
    assert(
      !fromExternalUrl,
      'toMultipartFileChunked() not available when uploading from external urls',
    );
    Stream<List<int>> chunkStream;

    if (byteData != null) {
      chunkStream = Stream.fromIterable(
        [byteData!.buffer.asUint8List(start, end - start)],
      );
    } else if (bytesData != null) {
      chunkStream = Stream.fromIterable(
        [bytesData!.sublist(start, end)],
      );
    } else {
      chunkStream = File(filePath!).openRead(start, end);
    }

    return MultipartFile(
      chunkStream,
      end - start,
      filename: identifier,
    );
  }

  /// common function to generate form data
  /// Override the default upload preset (when [CloudinaryPublic] is instantiated) with this one (if specified).
  Map<String, dynamic> toFormData({
    required String uploadPreset,
  }) {
    final Map<String, dynamic> data = {
      'upload_preset': uploadPreset,
      if (publicId != null) 'public_id': publicId,
      if (folder != null) 'folder': folder,
      if (tags != null && tags!.isNotEmpty) 'tags': tags!.join(','),
    };

    if (context != null && context!.isNotEmpty) {
      String context = '';

      this.context!.forEach((key, value) {
        context += '|$key=$value';
      });

      // remove the extra `|` at the beginning
      data['context'] = context.replaceFirst('|', '');
    }

    return data;
  }

  List<MultipartFile> createChunks(
    int _chunksCount,
    int _maxChunkSize,
  ) {
    List<MultipartFile> _chunks = [];

    for (int i = 0; i < _chunksCount; i++) {
      int _start = i * _maxChunkSize;
      int _end = min(fileSize, _start + _maxChunkSize);
      _chunks.add(toMultipartFileChunked(
        _start,
        _end,
      ));
    }
    return _chunks;
  }
}
