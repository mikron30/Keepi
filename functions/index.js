const crypto = require('crypto');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { GoogleAuth } = require('google-auth-library');
const sharp = require('sharp');

initializeApp();

const db = getFirestore();
const bucket = getStorage().bucket();
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});

const MODEL_FALLBACKS = [
  'gemini-3.8-flash',
  'gemini-3.5-flash-lite',
];

const CATEGORIES = [
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

const CONDITIONS = [
  'new',
  'like_new',
  'good',
  'fair',
  'poor',
  'unknown',
];

exports.processScanJob = onDocumentCreated(
  {
    document: 'scanJobs/{jobId}',
    region: 'europe-west1',
    timeoutSeconds: 540,
    memory: '2GiB',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const jobId = event.params.jobId;
    const jobRef = snapshot.ref;
    const job = snapshot.data();

    if (job.status !== 'queued') {
      return;
    }

    const sourcePath = job.sourceStoragePath;
    const sourceUrl = job.sourceUrl || null;

    if (!sourcePath) {
      await failJob(jobRef, 'Missing sourceStoragePath.');
      return;
    }

    try {
      await updateJob(jobRef, {
        status: 'preparing',
        stage: 'preparing',
        progress: 0.02,
        message: 'Preparing image on Keepi servers...',
        processedCount: 0,
        identifiedCount: 0,
        failedItems: 0,
      });

      const [sourceRaw] = await bucket.file(sourcePath).download();
      const normalizedSource = await sharp(sourceRaw)
        .rotate()
        .jpeg({ quality: 92 })
        .toBuffer();

      const metadata = await sharp(normalizedSource).metadata();
      const width = metadata.width;
      const height = metadata.height;

      if (!width || !height) {
        throw new Error('Could not read normalized image dimensions.');
      }

      await updateJob(jobRef, {
        status: 'locating',
        stage: 'locating',
        progress: 0.05,
        message: 'AI is locating separate products...',
      });

      const firstPass = await detectThings({
        imageBytes: normalizedSource,
        pass: 1,
        existingDetections: [],
      });

      let detections = prepareDetections(firstPass);
      let dominantHint = dominantDetectionHint(detections);

      await updateJob(jobRef, {
        totalDetected: detections.length,
        progress: 0.08,
        message: `Found ${detections.length} products · checking for missed items...`,
      });

      const secondPass = await detectThings({
        imageBytes: normalizedSource,
        pass: 2,
        dominantHint,
        existingDetections: detections,
      });

      detections = mergeDetectionPasses(detections, secondPass);
      dominantHint = dominantDetectionHint(detections);

      if (isDenseCollection(detections, dominantHint) && detections.length < 80) {
        await updateJob(jobRef, {
          totalDetected: detections.length,
          progress: 0.11,
          message: `Found ${detections.length} products · running deep collection scan...`,
        });

        const thirdPass = await detectThings({
          imageBytes: normalizedSource,
          pass: 3,
          dominantHint,
          existingDetections: detections,
        });

        detections = mergeDetectionPasses(detections, thirdPass);
      }

      if (detections.length === 0) {
        throw new Error('Keepi could not find separate products in this image.');
      }

      const totalDetected = detections.length;

      await updateJob(jobRef, {
        status: 'identifying',
        stage: 'identifying',
        totalDetected,
        progress: 0.15,
        message: `Found ${totalDetected} products · identifying in parallel...`,
      });

      const results = [];
      const failures = [];
      const concurrency = 4;
      let processed = 0;

      for (let start = 0; start < detections.length; start += concurrency) {
        const group = detections.slice(start, start + concurrency);

        const groupResults = await Promise.all(
          group.map(async (detection, offset) => {
            const itemIndex = start + offset + 1;

            try {
              const crops = await createProductCrops({
                sourceBytes: normalizedSource,
                width,
                height,
                detection,
              });

              const recognition = await recognizeProduct({
                imageBytes: crops.recognitionBytes,
                hint: detection.hint,
                itemIndex,
                totalItems: totalDetected,
              });

              return {
                ok: true,
                itemIndex,
                detection,
                recognition,
                thumbnailBytes: crops.thumbnailBytes,
              };
            } catch (error) {
              return {
                ok: false,
                itemIndex,
                detection,
                error: compactError(error),
              };
            }
          }),
        );

        for (const result of groupResults) {
          processed++;
          if (result.ok) {
            results.push(result);
          } else {
            failures.push(result);
          }
        }

        await updateJob(jobRef, {
          processedCount: processed,
          identifiedCount: results.length,
          failedItems: failures.length,
          progress: identificationProgress(processed, totalDetected),
          message:
            `Processed ${processed}/${totalDetected} · ${results.length} identified`,
        });
      }

      // Retry only the failed crops once. This happens after the main parallel
      // pass so a temporary rate limit does not stall every other product.
      if (failures.length > 0) {
        await sleep(3000);

        await updateJob(jobRef, {
          status: 'retrying',
          stage: 'retrying',
          message: `Retrying ${failures.length} products that failed temporarily...`,
        });

        const retryFailures = [];

        for (let start = 0; start < failures.length; start += concurrency) {
          const group = failures.slice(start, start + concurrency);

          const retried = await Promise.all(
            group.map(async (failed) => {
              try {
                const crops = await createProductCrops({
                  sourceBytes: normalizedSource,
                  width,
                  height,
                  detection: failed.detection,
                });

                const recognition = await recognizeProduct({
                  imageBytes: crops.recognitionBytes,
                  hint: failed.detection.hint,
                  itemIndex: failed.itemIndex,
                  totalItems: totalDetected,
                });

                return {
                  ok: true,
                  itemIndex: failed.itemIndex,
                  detection: failed.detection,
                  recognition,
                  thumbnailBytes: crops.thumbnailBytes,
                };
              } catch (error) {
                return {
                  ok: false,
                  itemIndex: failed.itemIndex,
                  detection: failed.detection,
                  error: compactError(error),
                };
              }
            }),
          );

          for (const result of retried) {
            if (result.ok) {
              results.push(result);
            } else {
              retryFailures.push(result);
            }
          }

          await updateJob(jobRef, {
            identifiedCount: results.length,
            failedItems: retryFailures.length +
                Math.max(0, failures.length - (start + group.length)),
            message:
              `Retrying failed products · ${results.length} identified so far`,
          });
        }

        failures.length = 0;
        failures.push(...retryFailures);
      }

      // Final de-duplication happens only when two results refer to the same
      // physical region and normalize to the same name. Two copies of the
      // same book in different positions remain separate inventory items.
      const dedupedResults = finalDedup(results);

      await updateJob(jobRef, {
        status: 'saving_results',
        stage: 'saving_results',
        progress: 0.93,
        identifiedCount: dedupedResults.length,
        failedItems: failures.length,
        message: `Saving ${dedupedResults.length} recognized products...`,
      });

      await saveResults({
        jobId,
        jobRef,
        ownerId: job.ownerId,
        sourceUrl,
        sourceStoragePath: sourcePath,
        results: dedupedResults,
        failures,
      });

      await updateJob(jobRef, {
        status: 'completed',
        stage: 'completed',
        progress: 1,
        totalDetected,
        processedCount: totalDetected,
        identifiedCount: dedupedResults.length,
        failedItems: failures.length,
        finalCount: dedupedResults.length,
        message:
          `Completed · ${dedupedResults.length} products ready for review`,
        completedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await failJob(jobRef, compactError(error));
    }
  },
);

async function saveResults({
  jobId,
  jobRef,
  ownerId,
  sourceUrl,
  sourceStoragePath,
  results,
  failures,
}) {
  const itemsRef = jobRef.collection('items');
  const batch = db.batch();

  for (const result of results) {
    const cropPath =
      `users/${ownerId}/scanJobs/${jobId}/crops/crop_${result.itemIndex}.jpg`;

    const cropFile = bucket.file(cropPath);
    const cropUrl = await saveFileWithDownloadToken(
      cropFile,
      result.thumbnailBytes,
      'image/jpeg',
    );

    const itemRef = itemsRef.doc(`item_${String(result.itemIndex).padStart(3, '0')}`);

    batch.set(itemRef, {
      index: result.itemIndex,
      status: 'identified',
      hint: result.detection.hint,
      bbox: {
        xMin: result.detection.xMin,
        yMin: result.detection.yMin,
        xMax: result.detection.xMax,
        yMax: result.detection.yMax,
      },
      recognition: result.recognition,
      cropUrl,
      cropStoragePath: cropPath,
      sourceUrl,
      sourceStoragePath,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  for (const failed of failures) {
    const itemRef = itemsRef.doc(`failed_${String(failed.itemIndex).padStart(3, '0')}`);
    batch.set(itemRef, {
      index: failed.itemIndex,
      status: 'failed',
      hint: failed.detection.hint,
      bbox: {
        xMin: failed.detection.xMin,
        yMin: failed.detection.yMin,
        xMax: failed.detection.xMax,
        yMax: failed.detection.yMax,
      },
      error: failed.error,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
}

async function detectThings({
  imageBytes,
  pass,
  dominantHint,
  existingDetections,
}) {
  const passInstruction = pass === 1
    ? 'First localization pass: find every clearly separable inventory item.'
    : pass === 2
      ? 'Second exhaustive pass: find narrow, tightly packed, partially occluded, or easy-to-miss items.'
      : 'Final recovery pass: search only for remaining missed physical objects.';

  const existingInstruction = existingDetections.length === 0
    ? ''
    : `
These boxes were already found:
${existingDetections
      .slice(0, 100)
      .map((d) => `[${d.yMin},${d.xMin},${d.yMax},${d.xMax}] ${d.hint}`)
      .join('\n')}

Return ONLY genuinely missing physical items. Do not return a duplicate box for
an already-listed product just because you would draw the box differently.
`;

  const collectionInstruction = dominantHint
    ? `
The image appears to contain mostly "${dominantHint}" items. Be exhaustive for
that object type. Return one box per separate physical item.
`
    : '';

  const prompt = `
You are the object-localization stage of Keepi, a universal inventory app.

Look at the FULL image and locate every separate physical item that should
become its own inventory entry.

${passInstruction}
${collectionInstruction}
${existingInstruction}

Return JSON exactly in this shape:
{
  "objects": [
    {
      "hint": "book",
      "box2d": [yMin, xMin, yMax, xMax],
      "confidence": 95
    }
  ]
}

Rules:
- box2d coordinates are integers 0..1000.
- ONE box per physical item.
- Bookshelf: one box per visible book/spine, including thin books. Do not
  require the title to be readable during localization.
- Shoe rack: one box per clear matching pair if together, otherwise one shoe.
- Tool rack: one box per tool.
- Pantry/fridge: one box per package/container/product.
- Do not return shelves, racks, cupboards, rooms, tables, drawers, or furniture.
- Do not merge several neighboring products into one box.
- Avoid duplicate boxes.
- Return up to 100 detections.
`;

  const decoded = await callGeminiJson({
    imageBytes,
    prompt,
    maxOutputTokens: 10000,
  });

  const objects = Array.isArray(decoded.objects) ? decoded.objects : [];

  return objects
    .map(normalizeDetection)
    .filter((item) => item && item.confidence >= 20)
    .slice(0, 100);
}

async function recognizeProduct({
  imageBytes,
  hint,
  itemIndex,
  totalItems,
}) {
  const prompt = `
You are Keepi's detailed product recognizer.

This is a crop around ONE detected physical product from a larger collection.
It is product ${itemIndex} of ${totalItems}.
Generic localization hint: "${hint || 'item'}".

Identify the ONE main product centered in the crop.

Return JSON exactly in this shape:
{
  "name": "useful product name",
  "categoryId": "books",
  "subcategory": "",
  "brand": "",
  "model": "",
  "condition": "good",
  "description": "",
  "estimatedNewPriceIls": 0,
  "estimatedCurrentValueIls": 0,
  "confidence": 0,
  "searchKeywords": [],
  "expiryDate": "",
  "expiryDateSource": "not_applicable"
}

Rules:
- categoryId must be one of: ${CATEGORIES.join(', ')}.
- condition must be one of: ${CONDITIONS.join(', ')}.
- Never invent exact text, title, author, brand, or model.
- For a book, read title/author from the visible spine or cover when possible.
  If unreadable, use a useful generic name such as "Book".
- Focus on the central product; neighboring fragments are context only.
- Prices are approximate integer ILS. Use 0 when uncertain.
- confidence is 0..100 for identification confidence.
- Add useful English and Hebrew search keywords when possible.
- For food or drinks, always populate expiryDateSource.
- If a printed expiry / best-before / use-by date is clearly readable, set expiryDate to YYYY-MM-DD and expiryDateSource to "printed".
- If this is food/drink but no reliable printed date is visible, set expiryDate to "" and expiryDateSource to "unknown".
- For non-food items, set expiryDate to "" and expiryDateSource to "not_applicable".
- Never invent an exact expiry date.
`;

  const decoded = await callGeminiJson({
    imageBytes,
    prompt,
    maxOutputTokens: 2500,
  });

  return normalizeRecognition(decoded);
}

async function callGeminiJson({
  imageBytes,
  prompt,
  maxOutputTokens,
}) {
  const projectId = getProjectId();
  const client = await auth.getClient();
  const authHeaders = await client.getRequestHeaders();

  let lastError;

  for (const model of MODEL_FALLBACKS) {
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        const url =
          `https://aiplatform.googleapis.com/v1/projects/${projectId}/locations/global/publishers/google/models/${model}:generateContent`;

        const response = await fetch(url, {
          method: 'POST',
          headers: {
            ...authHeaders,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            contents: [
              {
                role: 'user',
                parts: [
                  { text: prompt },
                  {
                    inlineData: {
                      mimeType: 'image/jpeg',
                      data: imageBytes.toString('base64'),
                    },
                  },
                ],
              },
            ],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens,
              responseMimeType: 'application/json',
            },
          }),
        });

        const bodyText = await response.text();

        if (!response.ok) {
          throw new Error(
            `Vertex AI ${response.status} (${model}): ${bodyText.slice(0, 700)}`,
          );
        }

        const body = JSON.parse(bodyText);
        const text = body?.candidates?.[0]?.content?.parts
          ?.map((part) => part.text || '')
          .join('')
          .trim();

        if (!text) {
          throw new Error(`Vertex AI returned an empty response (${model}).`);
        }

        return parseJsonText(text);
      } catch (error) {
        lastError = error;
        const message = String(error).toLowerCase();
        const temporary =
          message.includes('429') ||
          message.includes('500') ||
          message.includes('503') ||
          message.includes('resource_exhausted') ||
          message.includes('rate limit') ||
          message.includes('timeout') ||
          message.includes('fetch failed') ||
          message.includes('socket') ||
          message.includes('connection');

        if (!temporary) {
          break;
        }

        if (attempt < 3) {
          await sleep(attempt === 1 ? 1800 : 4500);
        }
      }
    }
  }

  throw lastError || new Error('AI request failed.');
}

async function createProductCrops({
  sourceBytes,
  width,
  height,
  detection,
}) {
  const rawLeft = Math.round((detection.xMin / 1000) * width);
  const rawTop = Math.round((detection.yMin / 1000) * height);
  const rawRight = Math.round((detection.xMax / 1000) * width);
  const rawBottom = Math.round((detection.yMax / 1000) * height);

  const rawWidth = Math.max(1, rawRight - rawLeft);
  const rawHeight = Math.max(1, rawBottom - rawTop);

  const thumbRect = paddedRect({
    rawLeft,
    rawTop,
    rawRight,
    rawBottom,
    width,
    height,
    padX: Math.max(2, Math.round(rawWidth * 0.025)),
    padY: Math.max(2, Math.round(rawHeight * 0.025)),
  });

  const recognitionRect = paddedRect({
    rawLeft,
    rawTop,
    rawRight,
    rawBottom,
    width,
    height,
    padX: Math.max(4, Math.round(rawWidth * 0.22)),
    padY: Math.max(4, Math.round(rawHeight * 0.08)),
  });

  const thumbnailBytes = await sharp(sourceBytes)
    .extract(thumbRect)
    .jpeg({ quality: 90 })
    .toBuffer();

  let recognitionPipeline = sharp(sourceBytes)
    .extract(recognitionRect);

  const longestSide = Math.max(recognitionRect.width, recognitionRect.height);
  if (longestSide < 900) {
    const scale = 900 / longestSide;
    recognitionPipeline = recognitionPipeline.resize({
      width: Math.max(1, Math.round(recognitionRect.width * scale)),
      height: Math.max(1, Math.round(recognitionRect.height * scale)),
      fit: 'fill',
    });
  }

  const recognitionBytes = await recognitionPipeline
    .jpeg({ quality: 92 })
    .toBuffer();

  return {
    thumbnailBytes,
    recognitionBytes,
  };
}

function paddedRect({
  rawLeft,
  rawTop,
  rawRight,
  rawBottom,
  width,
  height,
  padX,
  padY,
}) {
  const left = Math.max(0, rawLeft - padX);
  const top = Math.max(0, rawTop - padY);
  const right = Math.min(width, rawRight + padX);
  const bottom = Math.min(height, rawBottom + padY);

  return {
    left,
    top,
    width: Math.max(1, right - left),
    height: Math.max(1, bottom - top),
  };
}

function prepareDetections(rawDetections) {
  const cleaned = rawDetections
    .filter((d) => d && d.xMax > d.xMin && d.yMax > d.yMin)
    .filter((d) => {
      const hint = normalizeHint(d.hint);
      const area = normalizedArea(d);

      if (isContainerHint(hint)) {
        return false;
      }
      if (area > 0.62) {
        return false;
      }
      if (isNarrowCollectionItem(hint) && area > 0.18) {
        return false;
      }

      return true;
    })
    .sort((a, b) => {
      if (Math.abs(a.yMin - b.yMin) < 35) {
        return a.xMin - b.xMin;
      }
      return a.yMin - b.yMin;
    });

  return dedupeDetections(cleaned).slice(0, 100);
}

function mergeDetectionPasses(existing, incoming) {
  return prepareDetections([...existing, ...incoming]);
}

function dedupeDetections(detections) {
  const result = [];

  for (const detection of detections) {
    const duplicateIndex = result.findIndex((existing) =>
      samePhysicalDetection(existing, detection));

    if (duplicateIndex === -1) {
      result.push(detection);
    } else if (detection.confidence > result[duplicateIndex].confidence) {
      result[duplicateIndex] = detection;
    }
  }

  return result;
}

function samePhysicalDetection(a, b) {
  return intersectionOverUnion(a, b) >= 0.52 ||
    intersectionOverSmallerArea(a, b) >= 0.76;
}

function finalDedup(results) {
  const sorted = [...results].sort((a, b) => a.itemIndex - b.itemIndex);
  const kept = [];

  for (const candidate of sorted) {
    const name = normalizeName(candidate.recognition.name);
    const duplicate = kept.some((existing) => {
      if (normalizeName(existing.recognition.name) !== name || !name) {
        return false;
      }
      return samePhysicalDetection(existing.detection, candidate.detection);
    });

    if (!duplicate) {
      kept.push(candidate);
    }
  }

  return kept;
}

function normalizeDetection(raw) {
  const box = Array.isArray(raw?.box2d) ? raw.box2d : null;
  if (!box || box.length < 4) {
    return null;
  }

  const yMin = clampNumber(box[0], 0, 1000);
  const xMin = clampNumber(box[1], 0, 1000);
  const yMax = clampNumber(box[2], 0, 1000);
  const xMax = clampNumber(box[3], 0, 1000);

  if (xMax <= xMin || yMax <= yMin) {
    return null;
  }

  return {
    hint: String(raw.hint || 'item').trim(),
    xMin,
    yMin,
    xMax,
    yMax,
    confidence: clampNumber(raw.confidence, 0, 100),
  };
}

function normalizeRecognition(raw) {
  const categoryId = CATEGORIES.includes(raw.categoryId)
    ? raw.categoryId
    : 'other';

  const condition = CONDITIONS.includes(raw.condition)
    ? raw.condition
    : 'unknown';

  const keywords = Array.isArray(raw.searchKeywords)
    ? raw.searchKeywords
      .map((value) => String(value).trim())
      .filter(Boolean)
      .slice(0, 30)
    : [];

  return {
    name: String(raw.name || 'Thing').trim(),
    categoryId,
    subcategory: String(raw.subcategory || '').trim(),
    brand: String(raw.brand || '').trim(),
    model: String(raw.model || '').trim(),
    condition,
    description: String(raw.description || '').trim(),
    estimatedNewPriceIls: Math.max(
      0,
      Math.round(Number(raw.estimatedNewPriceIls) || 0),
    ),
    estimatedCurrentValueIls: Math.max(
      0,
      Math.round(Number(raw.estimatedCurrentValueIls) || 0),
    ),
    confidence: clampNumber(raw.confidence, 0, 100),
    searchKeywords: keywords,
    expiryDate: normalizeExpiryDate(raw.expiryDate),
    expiryDateSource: normalizeExpiryDateSource(raw.expiryDateSource, categoryId),
  };
}

function normalizeExpiryDate(value) {
  const text = String(value || "").trim();
  if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(text)) {
    return "";
  }
  const parsed = new Date(`${text}T00:00:00Z`);
  return Number.isNaN(parsed.getTime()) ? "" : text;
}

function normalizeExpiryDateSource(value, categoryId) {
  const source = String(value || "").trim().toLowerCase();
  if (source === "printed" || source === "manual") {
    return source;
  }
  if (categoryId === "food" || categoryId === "drinks") {
    return "unknown";
  }
  return "not_applicable";
}

function parseJsonText(text) {
  let cleaned = String(text).trim();

  if (cleaned.startsWith('~~~')) {
    cleaned = cleaned
      .replace(/^~~~(?:json)?\s*/i, '')
      .replace(/\s*~~~$/, '');
  }

  if (cleaned.startsWith('```')) {
    cleaned = cleaned
      .replace(/^```(?:json)?\s*/i, '')
      .replace(/\s*```$/, '');
  }

  try {
    return JSON.parse(cleaned);
  } catch (_) {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');

    if (start >= 0 && end > start) {
      return JSON.parse(cleaned.slice(start, end + 1));
    }

    throw new Error('AI returned invalid JSON.');
  }
}

async function saveFileWithDownloadToken(file, bytes, contentType) {
  const token = crypto.randomUUID();

  await file.save(bytes, {
    resumable: false,
    metadata: {
      contentType,
      cacheControl: 'public,max-age=31536000',
      metadata: {
        firebaseStorageDownloadTokens: token,
      },
    },
  });

  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodeURIComponent(file.name)}?alt=media&token=${token}`
  );
}

async function updateJob(jobRef, data) {
  await jobRef.set(
    {
      ...data,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function failJob(jobRef, error) {
  await updateJob(jobRef, {
    status: 'failed',
    stage: 'failed',
    message: 'Background scan failed',
    error,
    failedAt: FieldValue.serverTimestamp(),
  });
}

function getProjectId() {
  if (process.env.GCLOUD_PROJECT) {
    return process.env.GCLOUD_PROJECT;
  }
  if (process.env.GCP_PROJECT) {
    return process.env.GCP_PROJECT;
  }
  if (process.env.FIREBASE_CONFIG) {
    try {
      return JSON.parse(process.env.FIREBASE_CONFIG).projectId;
    } catch (_) {
      // Continue to final error below.
    }
  }
  throw new Error('Could not resolve Google Cloud project id.');
}

function dominantDetectionHint(detections) {
  const counts = new Map();

  for (const detection of detections) {
    const hint = canonicalHint(detection.hint);
    if (!hint || hint === 'item' || hint === 'object') {
      continue;
    }
    counts.set(hint, (counts.get(hint) || 0) + 1);
  }

  let best = null;
  let bestCount = 0;

  for (const [hint, count] of counts.entries()) {
    if (count > bestCount) {
      best = hint;
      bestCount = count;
    }
  }

  return best;
}

function isDenseCollection(detections, dominantHint) {
  if (detections.length >= 12) {
    return true;
  }

  const hint = dominantHint || '';
  return detections.length >= 6 &&
    (
      hint.includes('book') ||
      hint.includes('shoe') ||
      hint.includes('bottle') ||
      hint.includes('tool') ||
      hint.includes('can') ||
      hint.includes('box')
    );
}

function isNarrowCollectionItem(hint) {
  return hint.includes('book') ||
    hint.includes('bottle') ||
    hint.includes('can') ||
    hint.includes('tool');
}

function isContainerHint(hint) {
  return hint.includes('bookshelf') ||
    hint === 'shelf' ||
    hint.includes('rack') ||
    hint.includes('cupboard') ||
    hint.includes('cabinet') ||
    hint === 'room' ||
    hint.includes('drawer');
}

function canonicalHint(value) {
  const hint = normalizeHint(value);

  if (hint.includes('book')) return 'book';
  if (hint.includes('shoe') || hint.includes('sneaker')) return 'shoe';
  if (hint.includes('bottle')) return 'bottle';
  if (
    hint.includes('tool') ||
    hint.includes('hammer') ||
    hint.includes('drill') ||
    hint.includes('screwdriver') ||
    hint.includes('wrench')
  ) {
    return 'tool';
  }
  if (hint.includes('can')) return 'can';

  return hint;
}

function normalizeHint(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9\u0590-\u05FF ]+/g, ' ')
    .trim();
}

function normalizeName(value) {
  return normalizeHint(value).replace(/\s+/g, ' ');
}

function normalizedArea(d) {
  return ((d.xMax - d.xMin) * (d.yMax - d.yMin)) / 1000000;
}

function intersectionOverUnion(a, b) {
  const intersection = intersectionArea(a, b);
  if (intersection <= 0) {
    return 0;
  }

  const areaA = (a.xMax - a.xMin) * (a.yMax - a.yMin);
  const areaB = (b.xMax - b.xMin) * (b.yMax - b.yMin);
  const union = areaA + areaB - intersection;

  return union <= 0 ? 0 : intersection / union;
}

function intersectionOverSmallerArea(a, b) {
  const intersection = intersectionArea(a, b);
  if (intersection <= 0) {
    return 0;
  }

  const areaA = (a.xMax - a.xMin) * (a.yMax - a.yMin);
  const areaB = (b.xMax - b.xMin) * (b.yMax - b.yMin);
  const smaller = Math.min(areaA, areaB);

  return smaller <= 0 ? 0 : intersection / smaller;
}

function intersectionArea(a, b) {
  const left = Math.max(a.xMin, b.xMin);
  const top = Math.max(a.yMin, b.yMin);
  const right = Math.min(a.xMax, b.xMax);
  const bottom = Math.min(a.yMax, b.yMax);

  if (right <= left || bottom <= top) {
    return 0;
  }

  return (right - left) * (bottom - top);
}

function identificationProgress(processed, total) {
  if (!total) {
    return 0.15;
  }
  return Math.min(0.91, 0.15 + (processed / total) * 0.76);
}

function clampNumber(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return min;
  }
  return Math.max(min, Math.min(max, Math.round(number)));
}

function compactError(error) {
  const message = error instanceof Error ? error.message : String(error);
  return message.replace(/\s+/g, ' ').trim().slice(0, 1200);
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
