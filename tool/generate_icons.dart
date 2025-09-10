import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const inputPath = 'assets/images/Logo.png';
  const outDir = 'assets/icons';
  const target = 1024; // Icon base size
  const safePct = 0.66; // Safe zone recommended for Android adaptive foreground

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input logo not found: $inputPath');
    exit(1);
  }

  Directory(outDir).createSync(recursive: true);
  final bytes = inputFile.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Cannot decode image: $inputPath');
    exit(2);
  }

  // Compute scale so content fits within the safe area
  final safe = (target * safePct).round();
  final scale = decoded.width > decoded.height
      ? safe / decoded.width
      : safe / decoded.height;
  final newW = (decoded.width * scale).round();
  final newH = (decoded.height * scale).round();
  final resized = img.copyResize(
    decoded,
    width: newW,
    height: newH,
    interpolation: img.Interpolation.cubic,
  );

  // Transparent foreground for Android adaptive icon
  final fg = img.Image(width: target, height: target);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  final offX = ((target - newW) / 2).round();
  final offY = ((target - newH) / 2).round();
  img.compositeImage(fg, resized, dstX: offX, dstY: offY);
  final fgOut = File('$outDir/icon_foreground.png');
  fgOut.writeAsBytesSync(img.encodePng(fg));

  // iOS full icon with white background, same padding
  final ios = img.Image(width: target, height: target);
  img.fill(ios, color: img.ColorRgba8(255, 255, 255, 255));
  img.compositeImage(ios, resized, dstX: offX, dstY: offY);
  final iosOut = File('$outDir/icon_ios.png');
  iosOut.writeAsBytesSync(img.encodePng(ios));

  stdout.writeln('Generated:\n - ${fgOut.path}\n - ${iosOut.path}');
}
