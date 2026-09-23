# Keepi architecture

## Product boundary

Keepi is built around a universal private object called a **Thing**.

A Thing can represent almost any physical asset or consumable. The inventory model does not decide whether the Thing is for sale or rent. Commerce is represented separately by a **Listing**.

This separation is intentional:

```text
Thing (private source of truth)
        |
        +---- Listing (public or semi-public offer)
        |
        +---- Valuation history
        |
        +---- Expiry / lifecycle
        |
        +---- Insurance / risk
        |
        +---- Availability
```

## Flutter

Feature-first structure:

```text
lib/
  app/
  core/
    firebase/
    router/
    theme/
  features/
    add_thing/
    explore/
    home/
    inventory/
      domain/
      data/
      presentation/
    marketplace/
    profile/
    requests/
    shell/
```

As features grow, each feature can add `data/`, `domain/` and `presentation/` without forcing unnecessary abstraction in the first build.

## Firebase collections

Planned collections:

```text
/users
/things
/listings
/categories
/requests
/bookings
/transactions
/messages
/reviews
/priceHistory
/notifications
/insuranceQuotes
```

## Privacy

- Things are private by default.
- Listings are separate documents.
- Exact home/storage location stays private.
- Public search should use only an approximate area, distance or intentionally shared pickup point.
- High-value categories will add stronger identity, insurance, deposit and transaction controls.

## Category extensions

The base Thing stays universal. Category modules add optional fields and rules.

Examples:

- Vehicle: mileage, fuel/battery, licence requirements, insurance.
- Property: check-in/out, guests, cleaning, deposit.
- Food: expiry date, opened date, storage conditions.
- Tools: power source, model, included accessories.
- Wine: winery, vintage, opened date, recommended consumption window.

## Search

Search starts with Firestore-compatible fields and search keywords. Search is behind a service boundary so it can later move to Algolia, Typesense or Elasticsearch without redesigning the UI.

## AI flow

```text
Photo
  -> image recognition
  -> OCR / barcode when useful
  -> product candidate
  -> category
  -> structured attributes
  -> price/valuation candidates
  -> user confirmation
  -> Thing
```

AI output should be structured data, not free-form text.
