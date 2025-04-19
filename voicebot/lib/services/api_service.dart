import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class ApiService {
  // Updated Hugging Face Spaces URL - use proper API endpoints
  static const String _englishModelUrl =
      "https://nikjhonshon-voicecontrolledcar.hf.space"; // Direct API URL format
  static const String _nonEnglishModelUrl =
      "https://nikjhonshon-multilingual.hf.space"; // Direct API URL format

  // Correct endpoint for Hugging Face Spaces Gradio API
  static const String _speechToCommandEndpoint = '/api/predict';

  // Timeout duration for requests
  static const Duration _requestTimeout = Duration(seconds: 60);

  /// Get the appropriate model URL based on language
  static String _getModelUrlForLanguage(String language) {
    if (language.toLowerCase() == 'en') {
      return _englishModelUrl;
    } else {
      return _nonEnglishModelUrl;
    }
  }

  /// Process audio file and return the recognized command
  static Future<String> processAudioCommand(
    String audioFilePath,
    String language,
  ) async {
    try {
      debugPrint(
        'Processing audio file: $audioFilePath with language: $language',
      );

      // Try multiple approaches to find one that works
      return await tryMultipleApproaches(audioFilePath, language);
    } catch (e) {
      debugPrint('Error processing audio command: $e');
      if (e is TimeoutException) {
        return 'Error: Request timed out';
      }
      return 'Error: ${e.toString()}';
    }
  }

  /// Try multiple API approaches to find one that works
  static Future<String> tryMultipleApproaches(
    String audioFilePath,
    String language,
  ) async {
    // List of URLs to try
    final urlsToTry = [
      "https://nikjhonshon-voicecontrolledcar.hf.space/run/predict",
      "https://huggingface.co/spaces/Nikjhonshon/VoiceControlledCar/run/predict",
      "https://api-inference.huggingface.co/models/Nikjhonshon/VoiceControlledCar",
      // Add the correct URL when you find it
    ];

    // For logging
    debugPrint("Trying multiple API endpoints to find one that works");

    for (var url in urlsToTry) {
      try {
        debugPrint("Attempting with URL: $url");
        String result = await _submitWithUrl(url, audioFilePath, language);
        if (!result.startsWith("Error:")) {
          // Success! Return the successful result
          return result;
        }
        // If we got an error, try the next URL
        debugPrint("Failed with URL: $url. Trying next...");
      } catch (e) {
        debugPrint("Exception with URL $url: $e");
        // Continue to next URL
      }
    }

    // If all approaches failed
    return "Error: Could not connect to any known API endpoint";
  }

  /// Helper to try a specific URL with appropriate payload
  static Future<String> _submitWithUrl(
    String url,
    String audioFilePath,
    String language,
  ) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      return "Error: Audio file not found";
    }

    final bytes = await file.readAsBytes();

    // Try different payload formats

    try {
      // Approach 1: JSON with base64
      final base64Audio = base64Encode(bytes);
      final fileName = file.uri.pathSegments.last;
      debugPrint("File name: $fileName");
      final jsonResponse = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': fileName,
              'data': "data:audio/wave;base64,$base64Audio",
            }),
          )
          .timeout(_requestTimeout);

      if (jsonResponse.statusCode == 200) {
        // Process successful response
        debugPrint("Success with JSON base64 approach");
        return _processResponse(jsonResponse);
      }

      // Approach 2: Raw binary
      final binaryResponse = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'audio/wav'},
            body: bytes,
          )
          .timeout(_requestTimeout);

      if (binaryResponse.statusCode == 200) {
        // Process successful response
        debugPrint("Success with raw binary approach");
        return _processResponse(binaryResponse);
      }

      // Approach 3: Multipart
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFilePath),
      );
      request.fields['language'] = language;

      final streamedResponse = await request.send().timeout(_requestTimeout);
      final multipartResponse = await http.Response.fromStream(
        streamedResponse,
      );

      if (multipartResponse.statusCode == 200) {
        // Process successful response
        debugPrint("Success with multipart approach");
        return _processResponse(multipartResponse);
      }

      return "Error: All request formats failed with status codes: ${jsonResponse.statusCode}, ${binaryResponse.statusCode}, ${multipartResponse.statusCode}";
    } catch (e) {
      return "Error: Exception during request: $e";
    }
  }

  /// Process a successful response
  static String _processResponse(http.Response response) {
    try {
      final jsonResponse = jsonDecode(response.body);
      debugPrint('JSON response: $jsonResponse');

      String command = "";

      if (jsonResponse.containsKey('data')) {
        final data = jsonResponse['data'];
        if (data is List && data.isNotEmpty) {
          command = data[0].toString();
        } else {
          command = data.toString();
        }
      } else if (jsonResponse.containsKey('result')) {
        command = jsonResponse['result'].toString();
      } else {
        command = jsonResponse.toString();
      }

      command = command.replaceAll('"', '').trim();
      return command;
    } catch (e) {
      // If JSON parsing fails, return the raw response
      return response.body.trim();
    }
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
