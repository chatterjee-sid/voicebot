import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/command_model.dart';

class ApiService {
  // Real Hugging Face model URLs for speech command recognition
  static const String englishModelUrl =
      'https://api-inference.huggingface.co/models/facebook/wav2vec2-base-960h';
  static const String regionalModelUrl =
      'https://api-inference.huggingface.co/models/ai4bharat/indicwav2vec-transformer';

  // You should replace this with your actual Hugging Face API token
  static const String huggingFaceApiToken = 'hf_your_token_here';

  // Getter for the base URL to be used in settings screen
  static String get baseUrl => englishModelUrl.split('/models/')[0];

  // Get the appropriate model URL based on language
  static String getModelUrlForLanguage(String languageCode) {
    // Use English model for English, regional model for others
    switch (languageCode) {
      case 'en':
        return englishModelUrl;
      case 'hi':
      case 'gu':
        return regionalModelUrl;
      default:
        return englishModelUrl; // Default to English model
    }
  }

  // Send audio file to backend for processing
  static Future<String> processAudioCommand(
    String filePath,
    String languageCode,
  ) async {
    try {
      if (kDebugMode) {
        print('Sending audio file at path: $filePath');
        print('Using language: $languageCode');
      }

      // Verify file exists
      final audioFile = File(filePath);
      if (!await audioFile.exists()) {
        throw Exception('Audio file not found at path: $filePath');
      }

      final fileSize = await audioFile.length();
      if (kDebugMode) {
        print('Audio file size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      }

      // Determine which model to use based on the language
      final modelUrl = getModelUrlForLanguage(languageCode);
      if (kDebugMode) {
        print('Using model URL: $modelUrl');
      }

      // Read the audio file as bytes
      final bytes = await audioFile.readAsBytes();

      // Send request directly to Hugging Face inference API
      final response = await http.post(
        Uri.parse(modelUrl),
        headers: {
          'Authorization': 'Bearer $huggingFaceApiToken',
          'Content-Type': 'audio/wav',
        },
        body: bytes,
      );

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // Extract just the action/command from the response
        String action = '';

        // Handle the specific response format from Hugging Face
        if (jsonResponse is List && jsonResponse.isNotEmpty) {
          // If response is a list of results, get the first one
          final result = jsonResponse[0];
          action = result['label'] ?? result['action'] ?? '';
        } else if (jsonResponse is Map) {
          // If response is a single result object
          action = jsonResponse['label'] ?? jsonResponse['action'] ?? '';
        } else if (jsonResponse is String) {
          // Some models might return a direct string
          action = jsonResponse;
        }

        // If we couldn't extract a valid action
        if (action.isEmpty) {
          throw Exception('Could not extract action from model response');
        }

        return action;
      } else {
        // For development/debugging, provide more error details
        if (kDebugMode) {
          print('Error response: ${response.body}');
        }
        throw Exception(
          'Failed to process audio: ${response.statusCode} - ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing audio: $e');
      }

      // In debug mode, return a mock action for testing
      if (kDebugMode) {
        final mockActions = {
          'en': ['forward', 'backward', 'left', 'right', 'stop'],
          'hi': ['forward', 'backward', 'left', 'right', 'stop'],
          'gu': ['forward', 'backward', 'left', 'right', 'stop'],
        };

        // Pick a random action based on the language
        final actions = mockActions[languageCode] ?? mockActions['en']!;
        final randomIndex =
            DateTime.now().millisecondsSinceEpoch % actions.length;
        return actions[randomIndex];
      }

      // In production, return an error
      return 'error';
    }
  }

  // Check server status
  static Future<bool> checkServerStatus() async {
    try {
      // Check the status of both models
      final englishModelResponse = await http
          .head(
            Uri.parse(englishModelUrl),
            headers: {'Authorization': 'Bearer $huggingFaceApiToken'},
          )
          .timeout(const Duration(seconds: 5));

      final regionalModelResponse = await http
          .head(
            Uri.parse(regionalModelUrl),
            headers: {'Authorization': 'Bearer $huggingFaceApiToken'},
          )
          .timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        print('English model status: ${englishModelResponse.statusCode}');
        print('Regional model status: ${regionalModelResponse.statusCode}');
      }

      // Consider servers up if both return successful responses
      return englishModelResponse.statusCode < 400 &&
          regionalModelResponse.statusCode < 400;
    } catch (e) {
      if (kDebugMode) {
        print('Server connection failed: $e');
      }
      // For debugging, always return true to allow the app to function
      return kDebugMode ? true : false;
    }
  }
}
