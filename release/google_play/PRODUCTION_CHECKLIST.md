# Keepi production release checklist

## Generated in the repository
- [x] Privacy Policy
- [x] Account deletion web page
- [x] In-app account deletion entry point
- [x] Terms of Use
- [x] Mandatory Terms acceptance after sign-in
- [x] Support page
- [x] UGC reporting and blocking tools
- [x] Firestore rules for private blocks and safety reports
- [x] AdMob banner IDs
- [x] UMP consent flow before ad requests
- [x] app-ads.txt
- [x] Android upload-key signing support
- [x] Package ID com.mikron30.keepi
- [x] Android target API 36
- [x] Google Play Hebrew listing copy
- [x] Google Play English listing copy
- [x] Data Safety answer sheet
- [x] Reviewer-access instructions
- [x] Release notes
- [x] Play Store asset export script
- [x] Production candidate version code 6

## Run on the Windows build machine
1. git pull
2. .\setup_keepi.cmd -RunTarget none
   - This refreshes Firebase registration and deploys Firestore/Storage rules.
3. .\publish_keepi_web.ps1
   - Publishes Privacy, Terms, Deletion, Support and app-ads.txt.
4. .\build_keepi_android.cmd
   - Creates the signed AAB.
5. dart run tool/export_play_store_assets.dart
   - Creates Play icon and feature graphic.

## Files to upload
AAB:
build\app\outputs\bundle\release\app-release.aab

Store icon:
release\google_play\assets\app_icon_512.png

Feature graphic:
release\google_play\assets\feature_graphic_1024x500.png

## Still requires real-world/manual input
- [ ] At least 2 actual phone screenshots from the working app
- [ ] Permanent Google-reviewer account + password entered privately in Play Console
- [ ] Content-rating questionnaire confirmation
- [ ] Closed test if Play Console requires it for this developer account
- [ ] Final Play Console review/Production submission
