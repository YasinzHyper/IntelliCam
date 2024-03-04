// ignore_for_file: avoid_print
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_v2/tflite_v2.dart';
// import 'package:path/path.dart' as path;

class ScanController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    initCamera();
    initTfLite();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
  }

  late CameraController cameraController;
  late List<CameraDescription> cameras;

  var imageHeight = 0, imageWidth = 0;
  Size previewSize = const Size(0, 0);
  var isCameraInitialized = false.obs;
  var cameraCount = 0;
  var isPlaying = true.obs;

  List<dynamic> results = [];

  initCamera() async {
    if (await Permission.camera.request().isGranted) {
      cameras = await availableCameras();

      cameraController = CameraController(
        cameras[0], //Rear Camera
        ResolutionPreset.high,
      );
      await cameraController.initialize().then((value) {
        //for every 10th frame
        cameraController.startImageStream((image) {
          cameraCount++;
          if (cameraCount % 10 == 0) {
            cameraCount = 0;
            imageHeight = image.height;
            imageWidth = image.width;
            previewSize = cameraController.value.previewSize!;
            objectDetector(image);
          }
          update();
        });
        update();
      });
      isCameraInitialized(true);
      isPlaying(true);
      update();
    } else {
      print("Permission denied!");
    }
  }

  initTfLite() async {
    await Tflite.loadModel(
      model: 'assets/ssd_mobilenet.tflite',
      labels: 'assets/ssd_mobilenet.txt',
      isAsset: true,
      numThreads: 1,
      useGpuDelegate: false,
    );
  }

  playPause() {
    if (cameraController.value.isInitialized) {
      if (isPlaying.value) {
        cameraController.pausePreview();
        isPlaying(false);
      } else {
        cameraController.resumePreview();
        isPlaying(true);
      }
      update();
    }
  }

  takePicture() async {
    if (cameraController.value.isInitialized) {
      
      var image = await cameraController.takePicture();
      await cameraController.pausePreview();
      isPlaying(false);
      update();
      print("Image path is ${image.path}");
      
      return image.path;
    }
  }

  objectDetector(CameraImage image) async {
    var detector = await Tflite.detectObjectOnFrame(
      bytesList: image.planes.map((e) => e.bytes).toList(),
      asynch: true,
      model: "SSDMobileNet",
      imageHeight: image.height,
      imageWidth: image.width,
      imageMean: 127.5,
      imageStd: 127.5,
      rotation: 90,
      threshold: 0.4,
      numResultsPerClass: 1,
    );

    if (detector != null && detector.isNotEmpty) {
      results = detector;
      print("Result is $results");
      update();
    }
  }
}
