# Keepi — Google Play Data safety answers

This file is a practical checklist based on the current Keepi code and Google Mobile Ads integration. Re-check it whenever SDKs or features change.

## Top-level questions

- Does your app collect or share any of the required user data types? **Yes**
- Is all user data encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **Yes**
  - In-app: Profile > Delete account & data
  - Web: https://keepi.web.app/app/delete-account.html

## Data collected by Keepi

### Personal info
**Name**
- Collected: Yes
- Required: Yes for email/password registration; may come from sign-in provider
- Purpose: App functionality, Account management
- Shared: No, except when a user deliberately publishes/interacts where display name is shown

**Email address**
- Collected: Yes
- Required: Yes for account/login
- Purpose: App functionality, Account management
- Shared: No

**User IDs**
- Collected: Yes (Firebase UID)
- Purpose: App functionality, Account management, Security/fraud prevention
- Shared: No

**Phone number**
- Collected: Optional
- Purpose: App functionality
- Shared: No by default

### Location
**Precise location**
- Collected: Optional and user-triggered
- Purpose: App functionality, nearby discovery
- Shared: No by default; location attached to a public Thing may be used to show relative nearby results

**Approximate location**
- Collected/shared by Google Mobile Ads through IP-derived location
- Purpose: Advertising, Analytics, Fraud prevention

### Photos and videos
**Photos**
- Collected: Optional when user takes/selects item photos
- Purpose: App functionality, AI item recognition
- Shared: Processed through Google/Firebase AI/Cloud services as service providers and may be visible to other users when the user makes an item public

### Messages
**Other in-app messages**
- Collected: Yes when users use chat
- Purpose: App functionality
- Shared: With the intended chat participant

### App activity
**Other user-generated content**
- Collected: Item names, descriptions, listings, inventory attributes, marketplace choices, reports
- Purpose: App functionality
- Shared: Public/friend-visible content only when selected by the user

**App interactions**
- Collected/shared automatically by Google Mobile Ads
- Purpose: Advertising, Analytics, Fraud prevention

### App info and performance
**Diagnostics**
- Collected/shared automatically by Google Mobile Ads
- Purpose: Analytics, Fraud prevention, App functionality

### Device or other IDs
- Collected/shared automatically by Google Mobile Ads
- Purpose: Advertising, Analytics, Fraud prevention

## Advertising
Play Console > App content > Ads:
- **Yes, the app contains ads**

## Notes
- Keep this declaration aligned with the Privacy Policy.
- Google Mobile Ads disclosures may change with SDK updates.
- If analytics, Crashlytics, payments, contacts, audio, or new SDKs are added, update this form.
