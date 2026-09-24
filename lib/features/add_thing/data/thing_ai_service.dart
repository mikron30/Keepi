import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../domain/thing_detection.dart';
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

  static Future<List<ThingDetection>> detectThings({
    required Uint8List imageBytes,
    required String mimeType,
    int pass = 1,
    String? dominantHint,
    List<ThingDetection> existingDetections = const [],
  }) async {
    final detectionSchema = Schema.object(
      properties: {
        'objects': Schema.array(
          items: Schema.object(
            properties: {
              'hint': Schema.string(),
              'box2d': Schema.array(items: Schema.integer()),
              'confidence': Schema.integer(),
            },
          ),
        ),
      },
    );

    final passInstruction = switch (pass) {
      1 =>
        'First localization pass: find every clearly separable inventory item.',
      2 =>
        'Second exhaustive pass: deliberately look for narrow, tightly packed, '
            'partially occluded, or easy-to-miss items that a first pass may skip.',
      _ =>
        'Final recovery pass: search specifically for remaining missed objects, '
            'especially between already-obvious neighboring objects.',
    };

    final collectionInstruction = dominantHint == null ||
            dominantHint.trim().isEmpty
        ? ''
        : '''
The first pass suggests this is mainly a collection of "$dominantHint" items.
Be especially exhaustive for that object type. Return ONE box per physical
item, even when many similar items are tightly packed next to each other.
''';

    final existingInstruction = existingDetections.isEmpty
        ? ''
        : '''
These boxes were already found in earlier passes:
__EXISTING_BOXES__

Return ONLY genuinely missing physical items. Do not return another box for an
already-listed object merely because you would draw its box a little differently.
'''.replaceFirst(
          '__EXISTING_BOXES__',
          existingDetections
              .take(100)
              .map(
                (d) =>
                    '[${d.yMin},${d.xMin},${d.yMax},${d.xMax}] ${d.hint}',
              )
              .join('\n'),
        );

    final prompt = '''
You are the object-localization stage of Keepi, a household inventory app.

Look at the FULL image and locate each separate physical item that should become
its own inventory entry. Do not divide the image into a grid.

$passInstruction
$collectionInstruction
$existingInstruction

Return ONLY lightweight detections. Detailed product identification happens in
a later call on each crop.

Bounding-box format:
- Return box2d as [yMin, xMin, yMax, xMax].
- Every coordinate is an integer from 0 to 1000.
- (0,0) is the top-left; (1000,1000) is the bottom-right.
- Make each box tight around ONE physical item.
- confidence is 0 to 100.
- hint is a short generic type, e.g. "book", "shoe pair", "hammer", "bottle".

Collection rules:
- Bookshelf: ONE box for EACH visible book/spine, including thin books.
  Count neighboring spines separately even when touching. Do not require the
  title to be readable during localization.
- Shoe rack: one box per clear pair when the matching pair is together;
  otherwise one box per shoe.
- Tool rack/box: one box per separate tool.
- Pantry/fridge: one box per separate package/container/product.
- Sports equipment: one box per separate item.
- Clothing: one box per visually separate garment when practical.
- Do NOT return the shelf, cupboard, room, drawer, rack, table, or storage
  furniture unless it is itself the intended inventory object.
- Do NOT merge a row/group of products into one box.
- Avoid duplicate boxes for the same physical object.
- Return up to 100 detections.
''';

    final decoded = await _generateJson(
      imageBytes: imageBytes,
      mimeType: mimeType,
      schema: detectionSchema,
      prompt: prompt,
      timeout: const Duration(seconds: 70),
    );

    final rawObjects = decoded['objects'];
    if (rawObjects is! List) {
      throw StateError('AI returned an invalid detection result.');
    }

    return rawObjects
        .whereType<Map>()
        .map(
          (item) => ThingDetection.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.hasValidBox && item.confidence >= 20)
        .take(100)
        .toList();
  }

  static Future<ThingRecognition> recognizeDetectedThing({
    required Uint8List imageBytes,
    required String hint,
    required int itemIndex,
    required int totalItems,
  }) async {
    final prompt = '''
You are Keepi's detailed product recognizer.

This image is a CROP created around one product detected in a larger collection photo.
It is product $itemIndex of $totalItems.
The localization pass gave the generic hint: "$hint".

Identify the ONE main product centered in this crop and return structured inventory data.

Rules:
- Focus on the central detected object. Nearby fragments from neighboring objects are context only.
- Never invent exact text, title, brand, or model that is not reasonably visible.
- For a book, read the title/author from the visible spine or cover when possible. If the exact title cannot be read confidently, use a useful generic name such as "Book" rather than inventing a title.
- For shoes, identify the pair/model/type if visible.
- For tools, identify the specific tool type and brand/model only if visible.
- categoryId must use the provided enum.
- Use categoryId "books" for books.
- condition is a visual estimate only.
- Prices must be approximate integer Israeli shekels (ILS); use 0 when too uncertain.
- confidence is 0 to 100 for identification confidence.
- description should be one or two factual sentences.
- searchKeywords should include useful English and Hebrew terms where possible.
''';

    final decoded = await _generateJson(
      imageBytes: imageBytes,
      mimeType: 'image/jpeg',
      schema: _thingSchema,
      prompt: prompt,
      timeout: const Duration(seconds: 50),
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
      timeout: const Duration(seconds: 90),
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

  static Future<List<ThingRecognition>> recognizeMultipleTile({
    required Uint8List imageBytes,
    required int tileIndex,
    required int totalTiles,
  }) async {
    final schema = Schema.object(
      properties: {
        'things': Schema.array(items: _thingSchema),
      },
    );

    final prompt = '''
You are Keepi's focused multi-item scanner.

This image is scan area $tileIndex of $totalTiles from a larger photo that contains a collection of similar household items.

Identify every distinct useful physical item visible in THIS CROP only.

Examples:
- bookshelf: each readable book is a separate item
- shoe rack: each distinct pair/model of shoes is a separate item
- tool rack: each separate tool is a separate item
- pantry/fridge: each distinct product/container is a separate item
- sports shelf: each separate piece of equipment is a separate item

Rules:
- Return no more than 15 items from this crop.
- Do not return the shelf, cupboard, room, rack, or storage furniture unless it is clearly the intended item.
- Never invent a title, brand, model, or label that is not reasonably readable/visible.
- For books, read spine/cover titles. Skip books whose title cannot be read with reasonable confidence.
- If part of an item is cut off at an edge, include it only if it is still identifiable.
- categoryId must use the provided enum.
- Use categoryId "books" for books.
- condition is a visual estimate only.
- Prices are approximate integer Israeli shekels (ILS); use 0 when uncertain.
- confidence is 0 to 100 for identification confidence.
- description should be concise and factual.
- searchKeywords should include useful English and Hebrew terms where possible.
''';

    final decoded = await _generateJson(
      imageBytes: imageBytes,
      mimeType: 'image/jpeg',
      schema: schema,
      prompt: prompt,
      timeout: const Duration(seconds: 60),
    );

    final rawThings = decoded['things'];
    if (rawThings is! List) {
      throw StateError('AI returned an invalid tile result.');
    }

    return rawThings
        .whereType<Map>()
        .map(
          (item) => ThingRecognition.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.name.trim().isNotEmpty)
        .take(15)
        .toList();
  }

  static Future<Map<String, dynamic>> _generateJson({
    required Uint8List imageBytes,
    required String mimeType,
    required Schema schema,
    required String prompt,
    Duration timeout = const Duration(seconds: 45),
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

      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await model.generateContent([
            Content.multi([
              TextPart(prompt),
              InlineDataPart(mimeType, imageBytes),
            ]),
          ]).timeout(timeout);

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

          if (attempt < 3) {
            await Future<void>.delayed(
              Duration(seconds: attempt == 1 ? 2 : 5),
            );
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
        message.contains('timeout') ||
        message.contains('failed to fetch') ||
        message.contains('clientexception') ||
        message.contains('network error') ||
        message.contains('connection reset') ||
        message.contains('429') ||
        message.contains('resource_exhausted') ||
        message.contains('resource exhausted') ||
        message.contains('too many requests') ||
        message.contains('rate limit') ||
        message.contains('quota');
  }
}
