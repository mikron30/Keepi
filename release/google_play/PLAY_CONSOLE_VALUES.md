# Keepi — exact Google Play Console values

## Identity
- App name: **Keepi**
- Package name: **com.mikron30.keepi**
- Default language: Hebrew (iw-IL)
- App or game: **App**
- Free or paid: **Free**
- Category: **Lifestyle**
- Target audience: **18 and over**

## URLs
- Privacy Policy: https://keepi.web.app/app/privacy.html
- Account deletion: https://keepi.web.app/app/delete-account.html
- Terms of Use: https://keepi.web.app/app/terms.html
- Support: https://keepi.web.app/app/support.html
- Developer website: https://keepi.web.app/app/
- app-ads.txt: https://keepi.web.app/app-ads.txt

## App content
- Ads: **Yes**
- App access: **Restricted — login required**
- User-generated content: **Yes** (public listings and chat)
- Target audience: adults 18+
- Contains in-app purchases: **No for this release** (Premium can be added later)
- Financial features: **No** unless direct in-app payments are added later
- Health features: **No**
- News app: **No**
- Government app: **No**

## UGC compliance now present
- Terms acceptance required after sign-in
- Terms prohibit objectionable/illegal content
- Report user in chat
- Block user in chat
- Report listing in Explore
- Block listing owner / hide blocked owners from Explore

## Android
- applicationId: com.mikron30.keepi
- Target SDK: API 36 / Android 16
- Release signing: upload-keystore.jks
- Current production-candidate version code: 6

## Contact
- Privacy/support email: mikron30@gmail.com

## Before pressing Production
1. Publish Firebase Hosting so privacy/terms/deletion/support URLs are live.
2. Deploy Firestore rules so reports/blocks are allowed.
3. Configure AdMob Privacy & messaging message for EEA/UK/Switzerland; Keepi now invokes UMP before requesting ads.
4. Build and upload the signed version-code-6 AAB.
5. Create a permanent reviewer login and enter it under App access.
6. Complete Data safety using DATA_SAFETY.md.
7. Complete content rating truthfully, including user communication/UGC and ads.
8. Upload store icon, feature graphic and at least 2 real phone screenshots.
9. If the Play developer account is a personal account created after 13 Nov 2023, complete the required closed test before Production access.
