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

  static Future<ThingRecognition> recognize({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final schema = Schema.object(
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

    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.8-flash',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
      ),
    );

    const prompt = '''
You are the visual recognition engine for Keepi, a universal inventory app.

Analyze the single main physical item in this photo and return structured data.

Rules:
- Identify only what is reasonably supported by the image.
- Never invent an exact brand or model. If unreadable or uncertain, return an empty string.
- Use a short, useful marketplace-style item name.
- categoryId must use the provided enum.
- subcategory should be concise, such as "Drills", "Hair dryers", "Red wine", or "Bicycles".
- condition is a visual estimate only.
- Prices must be integer Israeli shekels (ILS).
- estimatedNewPriceIls is an approximate typical new retail price, not a fake exact quote.
- estimatedCurrentValueIls is an approximate second-hand value for the visible condition.
- If pricing is too uncertain, use 0.
- confidence is 0 to 100 and should reflect recognition confidence, not price confidence.
- description should be one or two factual sentences.
- searchKeywords should contain useful English and Hebrew search terms when possible, plus brand/model if known.
''';

    final response = await model.generateContent([
      Content.multi([
        const TextPart(prompt),
        InlineDataPart(mimeType, imageBytes),
      ]),
    ]);

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw StateError('AI returned an empty result.');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('AI returned an invalid recognition result.');
    }

    return ThingRecognition.fromJson(decoded);
  }
}
