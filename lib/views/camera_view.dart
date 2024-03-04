import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intellicam/controller/scan_controller.dart';
import '../widgets/bndbox.dart';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

class CameraView extends StatelessWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.sizeOf(context);
    // var tmp = screen;
    var screenH = math.max(screen.height, screen.width);
    var screenW = math.min(screen.height, screen.width);

    Future<Uint8List> cropImage(
      String imagePath,
      int previewH,
      int previewW,
      double x,
      double y,
      double w,
      double h,
    ) async {
      double scaleW, scaleH, x1, y1, w1, h1;

      if (screenH / screenW > previewH / previewW) {
        scaleW = screenH / previewH * previewW;
        scaleH = screenH;
        var difW = (scaleW - screenW) / scaleW;
        x1 = (x - difW / 2) * scaleW;
        w1 = w * scaleW;
        if (x < difW / 2) w1 -= (difW / 2 - x) * scaleW;
        y1 = y * scaleH;
        h1 = h * scaleH;
      } else {
        scaleH = screenW / previewW * previewH;
        scaleW = screenW;
        var difH = (scaleH - screenH) / scaleH;
        x1 = x * scaleW;
        w1 = w * scaleW;
        y1 = (y - difH / 2) * scaleH;
        h1 = h * scaleH;
        if (y < difH / 2) h1 -= (difH / 2 - y) * scaleH;
      }

      // Read the image from file
      File imageFile = File(imagePath);
      List<int> imageBytes = await imageFile.readAsBytes();

      // Decode the image
      img.Image originalImage =
          img.decodeImage(Uint8List.fromList(imageBytes))!;

      // Crop the image based on coordinates and size
      img.Image croppedImage = img.copyCrop(
        originalImage,
        x: x1.toInt() + 165 /* math.max(0, x1).toInt() */,
        y: y1.toInt() + 150 /* math.max(0, y1).toInt() */,
        width: (w1*1.6).toInt(),
        height: (h1*2.0).toInt(),
      );

      // Encode the cropped image back to bytes
      List<int> croppedBytes = img.encodePng(croppedImage);

      return Uint8List.fromList(croppedBytes);
    }

    return Scaffold(
      body: GetBuilder<ScanController>(
        init: ScanController(),
        builder: (controller) {
          var objectList = controller.results;
          var imageH = controller.imageHeight;
          var imageW = controller.imageWidth;

          return controller.isCameraInitialized.value
              ? Stack(
                  children: [
                    OverflowBox(
                      maxHeight: screenH,
                      maxWidth: screenW,
                      child: CameraPreview(
                        controller.cameraController,
                      ),
                    ),
                    BndBox(
                      results: objectList,
                      previewH: math.max(imageH, imageW),
                      previewW: math.min(imageH, imageW),
                      screenH: screen.height,
                      screenW: screen.width,
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: FloatingActionButton(
                        onPressed: controller.playPause,
                        child: Icon(controller.isPlaying.value
                            ? Icons.pause
                            : Icons.play_arrow),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      left: 2,
                      child: FloatingActionButton(
                        onPressed: () async {
                          var path = await controller.takePicture();
                          showDialog(
                            context: context,
                            builder: (context) {
                              var w = objectList[0]["rect"]["w"];
                              var h = objectList[0]["rect"]["h"];
                              var x = objectList[0]["rect"]["x"];
                              var y = objectList[0]["rect"]["y"];
                              // print("width is ${w.toString()}");
                              // print("height is ${h.toString()}");
                              return Column(
                                children: [
                                  Center(
                                    child: FutureBuilder<Uint8List>(
                                      future: cropImage(
                                        path,
                                        math.max(imageH, imageW),
                                        math.min(imageH, imageW),
                                        x,
                                        y,
                                        w,
                                        h,
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                                ConnectionState.done &&
                                            snapshot.hasData) {
                                          return Image.memory(snapshot.data!);
                                        } else {
                                          return const CircularProgressIndicator();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Icon(Icons.camera),
                      ),
                    ),
                  ],
                )
              : const Center(child: Text("Loading Preview..."));
        },
      ),
    );
  }
}
