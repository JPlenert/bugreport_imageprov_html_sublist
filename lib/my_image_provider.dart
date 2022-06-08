import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class MyImageProvider extends ImageProvider<MyImageProvider> {
  final int testNo;

  MyImageProvider({
    required this.testNo,
  });

  Future<ui.Codec> _loadAsync(
    MyImageProvider key,
    DecoderCallback decode,
  ) async {
    try {
      assert(key == this);

      Uint8List bytes = await loadBytesAsync();

      if (bytes.lengthInBytes == 0) {
        throw Exception('Received empty image bytes');
      }

      return decode(bytes);
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        PaintingBinding.instance!.imageCache!.evict(key);
      });
      rethrow;
    }
  }

  Future<Uint8List> loadBytesAsync() async {
    /// ********************************************************************
    /// Load some image
    http.Response resp = await http.get(Uri.parse(
        'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Phalaenopsis_JPEG.png/220px-Phalaenopsis_JPEG.png'));

    /// ** Test 1 - just return the image bytes -> works
    if (testNo == 1) {
      return resp.bodyBytes;
    } else if (testNo == 2) {
      // ** Test 2 - image bytes from sublistview -> FAIL
      // Prefix the image bytes (0x00, 0x00 + image bytes)
      Uint8List newBytes = Uint8List(resp.bodyBytes.length + 2);
      for (int i = 0; i < resp.bodyBytes.length; i++) {
        newBytes[i + 2] = resp.bodyBytes[i];
      }
      // Create a Sublist view, and skip the leading 2 bytes
      var newList = Uint8List.sublistView(newBytes, 2);

      return newList;
    } else if (testNo == 3) {
      // ** Test 3 - image bytes from sublistview, and copy back to a list -> workd
      // Prefix the image bytes (0x00, 0x00 + image bytes)
      Uint8List newBytes = Uint8List(resp.bodyBytes.length + 2);
      for (int i = 0; i < resp.bodyBytes.length; i++) {
        newBytes[i + 2] = resp.bodyBytes[i];
      }

      // Create a Sublist view, and skip the leading 2 bytes
      var newList = Uint8List.sublistView(newBytes, 2);

      // Build list from sublistview
      return Uint8List.fromList(newList);
    }

    return Uint8List(0);
  }

  @override
  Future<MyImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MyImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(MyImageProvider key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1,
      debugLabel: key.toString(),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<MyImageProvider>('Image key', key),
      ],
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is MyImageProvider && other.testNo == testNo;
  }

  @override
  int get hashCode => testNo;
}
