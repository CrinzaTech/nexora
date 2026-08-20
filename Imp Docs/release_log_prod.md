# Crinza App — Production Release Log & Signing Reference

> Generated: 2026-06-10  
> Branch: `crinesta-prod` (merged from `dev`)  
> APK: `build/app/outputs/flutter-apk/app-release.apk` (83.4 MB)

---

## Commits in this Production Release

| Hash | Description |
|------|-------------|
| `21d4f01` | merge: dev → crinesta-prod (catalog, filters, OTP autofill, loaders, font scale cap) |
| `1651aef` | merge: catalog-impl → dev (catalog pagination, filters, OTP autofill, loaders) |
| `53a28ca` | feat: OTP SMS autofill, login/OTP loaders, system font scale cap, search bar fill fix |
| `3ae5240` | feat: inline search with debounce, filter sheet state persistence, course type chips, dynamic video player |
| `7d7e0b9` | feat: add course categories filtering and enforce 10-digit validation on phone input |

---

## Feature Summary

| Area | Change |
|------|--------|
| **Catalog** | Infinite scroll pagination (page-number based), inline search with 300 ms debounce + 3-char min |
| **Filters** | Course-type single-select chips, category chips, filter state persisted between sheet opens |
| **Video Player** | Static test URL removed — dynamic YouTube + network routing via `pod_player` |
| **OTP** | SMS auto-detection (`CodeAutoFill` mixin, Android SMS Retriever API), no `READ_SMS` permission |
| **Loaders** | Full-screen overlay on Login (OTP request) and OTP (verify/resend) pages |
| **System Font** | `textScaler` clamped to `1.0` in `MaterialApp.builder` — large accessibility fonts no longer break layouts |
| **Search Bar** | `filled: false` + `fillColor: Colors.transparent` — grey background removed |
| **OTP Timer** | Resend countdown increased from 30 s → 60 s |

---

## Android Signing Certificate

> [!IMPORTANT]  
> Keep `android/key.properties` and `android/upload-keystore.jks` **out of version control** (already in `.gitignore`). Never share the passwords in a public channel.

| Field | Value |
|-------|-------|
| **Keystore file** | `android/upload-keystore.jks` |
| **Alias** | `upload` |
| **Key algorithm** | SHA256withRSA |
| **Valid** | 2026-05-24 → 2053-10-09 |
| **Owner** | CN=Crinza, OU=Mobile, O=Crinesta, C=IN |
| **SHA-1 fingerprint** | `47:29:40:38:FB:DE:EC:A4:D1:80:F6:9B:CF:4C:61:3C:66:9B:1F:4C` |
| **SHA-256 fingerprint** | `5B:03:3A:26:C4:2E:85:08:D9:ED:26:53:39:EF:B5:1F:F1:92:BD:FB:4A:19:71:C3:AC:DE:2A:FD:76:5F:DF:00` |

---

## SMS Retriever API — App Hash

> [!IMPORTANT]  
> The backend **must** append the appropriate hash as the last line of every OTP SMS for Android SMS auto-detection to work. Without it, users must type the code manually.

Depending on which package name is built/released:

### 1. Dreams Vs Reality (Default Production)
```
SMS App Hash:  H60SVFfFPOZ
Package name:  com.crinesta.dvr
```

**Example OTP SMS format** (must be ≤ 140 bytes, hash on last line):
```
Your Crinza verification code is: 847291
H60SVFfFPOZ
```

### 2. Crinza (Staging / Alternative)
```
SMS App Hash:  RzpiueBdxJd
Package name:  com.crinesta.crinza
```

**Example OTP SMS format** (must be ≤ 140 bytes, hash on last line):
```
Your Crinza verification code is: 847291
RzpiueBdxJd
```

### How the hash is computed

```python
import hashlib, base64
cert_sha256 = hashlib.sha256(open('android/upload-keystore.jks.der','rb').read()).digest()
app_hash    = base64.urlsafe_b64encode(
                  hashlib.sha256(b'com.crinesta.dvr ' + cert_sha256).digest()
              )[:11].decode()
```

---

## Google Play Console — App Signing

If you use **Play App Signing** (recommended), Google re-signs the APK with their own key after upload. In that case:

1. Go to **Play Console → Setup → App integrity → App signing**
2. Use the SHA-1 / SHA-256 shown there (not from the upload keystore above)
3. Recompute the SMS hash using the Play-signing certificate for the active package name

---

## Build Configuration

| Setting | Value |
|---------|-------|
| `applicationId` | `com.crinesta.dvr` (Default) / `com.crinesta.crinza` |
| `minSdk` | flutter.minSdkVersion |
| `targetSdk` | flutter.targetSdkVersion |
| `versionCode` | 0.0.1+1 |
| `isMinifyEnabled` | `true` |
| `isShrinkResources` | `true` |
| ProGuard | `proguard-android-optimize.txt` + `proguard-rules.pro` |
| 16 KB page alignment | `useLegacyPackaging = false` |

---

## Next Steps

- [ ] Share **SMS App Hash** (`RzpiueBdxJd`) with backend team for production environment
- [ ] Verify Play Store SHA-256 if using Play App Signing and recompute hash if different
- [ ] QA test OTP auto-fill on a physical Android device with a SIM card using production build
- [ ] **Reminder**: This was a local merge commit. No pushes to remote repositories have been made.
