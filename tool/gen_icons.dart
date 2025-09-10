// Simple icon generator: pads the original logo into a square canvas to avoid cropping/stretching.
// Usage: dart run tool/gen_icons.dart <input> <bgColorHex> <paddingPercent>
// Generates assets/icons/icon_foreground.png (Android) and assets/icons/icon_ios.png (iOS)

import 'dart:io';
import 'package:image/image.dart' as img;

int _parseHex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return int.parse(h, radix: 16);
}

void main(List<String> args) {
  if (args.length < 1) {
    stderr.writeln(
        'Usage: dart run tool/gen_icons.dart <input> [bgColorHex=#FFFFFF] [paddingPercent=18]');
    exit(64);
  }
  final inputPath = args[0];
  final bg = args.length > 1 ? args[1] : '#FFFFFF';
  final paddingPct = args.length > 2 ? double.tryParse(args[2]) ?? 18.0 : 18.0;

  final bytes = File(inputPath).readAsBytesSync();
  final original = img.decodeImage(bytes);
  if (original == null) {
    stderr.writeln('Could not decode image: $inputPath');
    exit(65);
  }

  // Target sizes high enough; flutter_launcher_icons will downscale as needed
  const target = 1024;
  final size = target;
  final bgColor = _parseHex(bg);

  // Android foreground canvas: transparent
  final canvasAndroid = img.Image(width: size, height: size);
  img.fill(canvasAndroid, color: img.ColorRgba8(0, 0, 0, 0));

  // iOS full icon canvas: colored background
  final a = (bgColor >> 24) & 0xFF;
  final r = (bgColor >> 16) & 0xFF;
  final g = (bgColor >> 8) & 0xFF;
  final b = bgColor & 0xFF;
  final canvasIOS = img.Image(width: size, height: size);
  img.fill(canvasIOS, color: img.ColorRgba8(r, g, b, a));

  final pad = (paddingPct.clamp(0, 45) / 100.0) * size; // clamp padding 0..45%
  final maxContent = size - (pad * 2).round();
  // Scale original to fit within square, respecting aspect ratio
  final ratioW = maxContent / original.width;
  final ratioH = maxContent / original.height;
  final ratio = ratioW < ratioH ? ratioW : ratioH;
  final newW = (original.width * ratio).round();
  final newH = (original.height * ratio).round();
  final resized = img.copyResize(original, width: newW, height: newH);

  final dx = ((size - newW) / 2).round();
  final dy = ((size - newH) / 2).round();
  // Composite resized icon onto both canvases
  img.compositeImage(canvasAndroid, resized, dstX: dx, dstY: dy);
  img.compositeImage(canvasIOS, resized, dstX: dx, dstY: dy);

  // Write outputs
  Directory('assets/icons').createSync(recursive: true);
  File('assets/icons/icon_foreground.png')
      .writeAsBytesSync(img.encodePng(canvasAndroid));
  File('assets/icons/icon_ios.png').writeAsBytesSync(img.encodePng(canvasIOS));

  stdout.writeln(
      'Generated assets/icons/icon_foreground.png and icon_ios.png with padding ${paddingPct.toStringAsFixed(1)}%');
}
