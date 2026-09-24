import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../domain/thing_recognition.dart';

class ThingAiService {
  ThingAiService._();

  static const _categories = <String>[
    'home',
    'vehicles',
    'tools',
    'sports',
    'garden',
    'electronics',
    'food',
    'drinks',
    'books',
    'clothing',
    'baby',
    'camping',
    'real_estate',
    'personal_care',
    'other',
  ];

  static const _conditions = <String>[
    'new',
    'like_new',
    'good',
    'fair',
    'poor',
    'unknown',
  ];

  static const _modelFallbacks = <String>[
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
  ];

  static Schema get _thingSchema => Schema.object(
        properties: {
          'name': Schema.string(),
          'categoryId': Schema.enumString(enumValues: _categories),
          'subcategory': Schema.string(),
          'brand': Schema.string(),
          'model': Schema.string(),
          'condition': Schema.enumString(enumValues: _conditions),
          'description': Schema.string(),
          'estimatedNewPriceIls': Schema.integer(),
          'estimatedCurrentValueIls': Schema.integer(),
          'confidence': Schema.integer(),
          'searchKeywords': Schema.array(items: Schema.string()),
        },
      );

  static Future<ThingRecognition> recognize({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    const prompt = '''
You are the visual recognition engine for Keepi, a universal inventory app.

Analyze the single main physical item in this photo and return structured data.

Rules:
- Identify only what is reasonably supported by the image.
- Never invent an exact brand or model. If unreadable or uncertain, return an empty string.
- Use a short, useful marketplace-style item name.
- categoryId must use the provided enum.
- subcategory should be concise, such as "Drills", "Hair dryers", "Red wine", "Books", or "Bicycles".
- condition is a visual estimate only.
- Prices must be integer Israeli shekels (ILS).
- estimatedNewPriceIls is an approximate typical new retail price, not a fake exact quote.
- estimatedCurrentValueIls is an approximate second-hand value for the visible condition.
- If pricing is too uncertain, use 0.
- confidence is 0 to 100 and should reflect recognition confidence, not price confidence.
- description should be one or two factual sentences.
- searchKeywords should contain useful English and Hebrew search terms when possible, plus brand/model if known.
''';

    final decoded = await _generateJson(
      imageBytes: imageBytes,
      mimeType: mimeType,
      schema: _thingSchema,
      prompt: prompt,
    );

    return ThingRecognition.fromJson(decoded);
  }

  static Future<List<ThingRecognition>> recognizeMultiple({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final schema = Schema.object(
      properties: {
        'things': Schema.array(items: _thingSchema),
      },
    );

    const prompt = '''
You are Keepi's multi-item inventory scanner.

Analyze this photo and identify every distinct useful physical item that is reasonably visible.
Return each detected item as a separate Thing.

This mode is specifically designed for shelves, bookcases, cupboards, tool racks, refrigerators, closets, and rooms.

Important bookshelf rules:
- Treat each visible book as a separate item.
- Read the title from the spine or cover when legible.
- If an author is clearly visible, include the author in description and searchKeywords.
- Never invent a book title. If the title cannot be read with reasonable confidence, skip that book.
- Do not return one generic "bookshelf" item when individual books can be identified.

General rules:
- Return at most 50 items.
- Skip duplicates caused by seeing the same item twice.
- Skip tiny/background objects that cannot be identified usefully.
- Never invent exact brand/model/title text.
- categoryId must use the provided enum.
- Use categoryId "books" for books.
- Prices are approximate integer Israeli shekels (ILS); use 0 if too uncertain.
- confidence is 0 to 100 for identification confidence.
- searchKeywords should include useful English and Hebrew terms where possible.
''';

    final decoded = await _generateJson(
      imageBytes: imageBytes,
      mimeType: mimeType,
      schema: schema,
      prompt: prompt,
    );

    final rawThings = decoded['things'];
    if (rawThings is! List) {
      throw StateError('AI returned an invalid multi-item result.');
    }

    return rawThings
        .whereType<Map>()
        .map((item) => ThingRecognition.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.name.trim().isNotEmpty)
        .take(50)
        .toList();
  }

  static Future<Map<String, dynamic>> _generateJson({
    required Uint8List imageBytes,
    required String mimeType,
    required Schema schema,
    required String prompt,
  }) async {
    Object? lastError;

    for (final modelName in _modelFallbacks) {
      final model = FirebaseAI.agentPlatform().generativeModel(
        model: modelName,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: schema,
        ),
      );

      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await model.generateContent([
            Content.multi([
              TextPart(prompt),
              InlineDataPart(mimeType, imageBytes),
            ]),
          ]).timeout(const Duration(seconds: 45));

          final text = response.text;
          if (text == null || text.trim().isEmpty) {
            throw StateError('AI returned an empty result.');
          }

          final decoded = jsonDecode(text);
          if (decoded is! Map<String, dynamic>) {
            throw StateError('AI returned invalid JSON.');
          }

          return decoded;
        } catch (error) {
          lastError = error;

          if (!_isTemporaryModelError(error)) {
            rethrow;
          }

          if (attempt < 2) {
            await Future<void>.delayed(Duration(seconds: attempt * 2));
          }
        }
      }
    }

    throw StateError(
      'Keepi AI is temporarily busy. Please try again in a moment. '
      'Last error: ${lastError ?? 'unknown'}',
    );
  }

  static bool _isTemporaryModelError(Object error) {
    final message = error.toString().toLowerCase();

    return message.contains('high demand') ||
        message.contains('server error [500]') ||
        message.contains('code": 500') ||
        message.contains('status": "internal') ||
        message.contains('503') ||
        message.contains('unavailable') ||
        message.contains('deadline') ||
        message.contains('timeout');
  }
}
