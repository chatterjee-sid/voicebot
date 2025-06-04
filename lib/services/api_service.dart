import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class ApiService {
  static const String _englishModelUrl =
      "https://nikjhonshon-voicecontrolledcar.hf.space/gradio_api"; // Direct API URL format
  static const String _nonEnglishModelUrl =
      "https://nikjhonshon-multilingual.hf.space/gradio_api"; // Direct API URL format

  // Get the appropriate model URL based on language
  static String _getModelUrlForLanguage(String language) {
    if (language.toLowerCase() == 'en') {
      return _englishModelUrl;
    } else {
      return _nonEnglishModelUrl;
    }
  }

  // Process audio file and return the recognized command
  static Future<String> processAudioCommand(
    String audioFilePath,
    String language,
  ) async {
    try {
      debugPrint(
        'Processing audio file: $audioFilePath with language: $language',
      );

      return await _submitToGradioSpace(
        audioFilePath: audioFilePath,
        language: language,
      );
    } catch (e) {
      debugPrint('Error processing audio command: $e');
      if (e is TimeoutException) {
        return 'Error: Request timed out';
      }
      return 'Error: ${e.toString()}';
    }
  }

  static Future<String> _submitToGradioSpace({
    required String audioFilePath,
    required String language,
  }) async {
    final file = File(audioFilePath);
    if (!await file.exists()) return "Error: File not found";
    final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
    final uploadUrl = _getModelUrlForLanguage(language);
    final sessionHash = _generateRandomSessionHash();

    try {
      // STEP 1: Upload the file using multipart/form-data
      final request = http.MultipartRequest(
        "POST",
        Uri.parse('$uploadUrl/upload?upload_id=$uploadId'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('files', audioFilePath),
      );

      debugPrint("Uploading file: $audioFilePath to $uploadUrl");

      final uploadResponse = await request.send();

      debugPrint(
        "Uploading file: $audioFilePath to $uploadUrl/upload?upload_id=$uploadId",
      );

      if (uploadResponse.statusCode != 200) {
        debugPrint("Upload failed with status ${uploadResponse.statusCode}");
        return "Error: Upload failed (${uploadResponse.statusCode})";
      }

      debugPrint("Upload successful, status: ${uploadResponse.statusCode}");

      final responseBody = await uploadResponse.stream.bytesToString();
      debugPrint("Upload response body: $responseBody");

      final uploaded = jsonDecode(responseBody);
      debugPrint("jsonDecode: $uploaded");
      final uploadedPath = uploaded[0];

      debugPrint("File uploaded: $uploadedPath");

      final filename = path.basename(audioFilePath);
      final mimeType = "audio/wav";

      // STEP 2: Prepare query payload
      final audioData = {
        "path": uploadedPath,
        "name": filename,
        "orig_name": filename,
        "size": await file.length(),
        "mime_type": mimeType,
        "url": '$uploadUrl/file=$uploadedPath',
        "meta": {"_type": "gradio.FileData"},
        "_type": "gradio.FileData",
      };
      final queuePayLoad = jsonEncode({
        "fn_index": 2,
        "session_hash": sessionHash,
        "event_data": null,
        "data": [audioData],
      });

      // STEP 3: Submit to queue
      final client = HttpClient();

      final queueRequest = await client.postUrl(
        Uri.parse('$uploadUrl/queue/join'),
      );
      queueRequest.headers.set('Content-Type', 'application/json');
      queueRequest.write(queuePayLoad);

      final queueResponse = await queueRequest.close();
      final completer = Completer<String>();

      if (queueResponse.statusCode != 200) {
        debugPrint("Join failed: ${queueResponse.statusCode} - $queueResponse");
        return "Error: Join failed (${queueResponse.statusCode})";
      }

      // STEP 4: Poll for result
      final dataRequest = await client.getUrl(
        Uri.parse('$uploadUrl/queue/data?session_hash=$sessionHash'),
      );
      final dataResponse = await dataRequest.close();

      final commandMap = {
        "Class 0": "Backward",
        "Class 3": "Forward",
        "Class 5": "Left",
        "Class 7": "Right",
        "Class 6": "No Operation",
      };

      dataResponse
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              debugPrint(line);
              if (line.startsWith("data: ")) {
                final jsonLine = line.substring(6).trim();
                debugPrint("SSE Line: $jsonLine");
                if (jsonLine == "PING") return;

                try {
                  final decoded = jsonDecode(jsonLine);
                  final msg = decoded["msg"];
                  debugPrint('Decoded message: $msg');
                  if (msg == "process_completed") {
                    final label = decoded["output"]["data"][1]['label'];
                    final result = commandMap[label];
                    debugPrint("Final result: $result");
                    completer.complete(result);
                  } else if (msg == "queue_full" || msg == "error") {
                    completer.complete("Error: ${decoded['error']}");
                  } else {
                    debugPrint("Unknown message: $msg");
                  }
                } catch (e) {
                  debugPrint("Error decoding JSON: $e");
                }
              }
            },
            onError: (e) {
              if (!completer.isCompleted) {
                completer.complete("Error: Stream failed: $e");
              }
            },
            onDone: () {
              if (!completer.isCompleted) {
                completer.complete("Error: Stream closed without result");
              }
            },
          );

      return await completer.future;
    } catch (e) {
      return "Error: Exception during request: $e";
    }
  }

  static String _generateRandomSessionHash() {
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      15,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  // Helper function to limit string length
  static int min(int a, int b) => a < b ? a : b;

  /// Check if the API service is available
  static Future<bool> checkServiceAvailability(String language) async {
    try {
      final modelUrl = _getModelUrlForLanguage(language);

      // Try to reach the model's home page instead of /health which might not exist
      final response = await http
          .get(Uri.parse(modelUrl))
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error checking API service: $e');
      return false;
    }
  }
}
