import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// 把背景图一次性"烘焙"成可直接贴屏的静态纹理：
///   1. 解码时就等比压到不超过 [maxWidth]（源图常是数千像素的相机图/壁纸，
///      全分辨率解码既慢又费显存，屏幕上根本看不出差别）；
///   2. 若 [blurSigma] > 0，把高斯模糊直接画进像素里。
///
/// 运行期从此只画一张普通纹理——没有每帧的 ImageFiltered/saveLayer。
/// 实时滤镜是进入首页时壁纸渲染卡顿、SnackBar 等动画掉帧的元凶，
/// 也会在 macOS/Impeller 上诱发把部分控件画成灰色色块的伪影。
///
/// [blurSigma] 与设置页滑杆一致，按逻辑像素理解；[logicalWidth] 是背景图
/// 铺满时对应的窗口逻辑宽度，用来把 sigma 换算到图片像素坐标，
/// 保证烘焙后的模糊程度和原来实时模糊的观感一致。
Future<Image> bakeBackgroundImage(
  Uint8List bytes, {
  required double blurSigma,
  required int maxWidth,
  required double logicalWidth,
}) async {
  final buffer = await ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ImageDescriptor.encoded(buffer);
  try {
    final codec = descriptor.width > maxWidth
        ? await descriptor.instantiateCodec(targetWidth: maxWidth)
        : await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    final decoded = frame.image;
    if (blurSigma <= 0) return decoded;

    final sigma = blurSigma * decoded.width / math.max(1.0, logicalWidth);
    final recorder = PictureRecorder();
    Canvas(recorder).drawImage(
      decoded,
      Offset.zero,
      Paint()
        ..imageFilter = ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    final picture = recorder.endRecording();
    final baked = await picture.toImage(decoded.width, decoded.height);
    picture.dispose();
    decoded.dispose();
    return baked;
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}
