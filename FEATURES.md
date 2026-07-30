# Proxinotes — Features & Roadmap

## Status Legend
- ✅ **Done** — fully implemented and working
- 🔶 **Partial** — implemented but missing edge cases or polish
- ⬜ **Planned** — not started

---

## Authentication
| Feature | Status | Notes |
|---------|--------|-------|
| Google Sign-In | ✅ | OAuth via `google_sign_in` + Supabase ID token |
| Username setup on first login | ✅ | Upsert to `users` table |
| Session persistence | ✅ | Supabase auto-restore |
| Sign out (clears cache + encryption key) | ✅ | `PageEncryptor.deleteKey()` + cache wipe |

---

## Content Browsing
| Feature | Status | Notes |
|---------|--------|-------|
| Subject-grouped grid view | ✅ | Grouped by subject with access badges |
| Real-time search | ✅ | `.ilike` on subject/chapter |
| Pull-to-refresh | ✅ | |
| Offline metadata cache | ✅ | SharedPreferences |
| Search by chapter name | ⬜ | Currently subject-only |

---

## Subscription & Payments
| Feature | Status | Notes |
|---------|--------|-------|
| Pricing plans from DB | ✅ | Fetched from `pricing_plans` table |
| Razorpay UPI Autopay | ✅ | Full subscription checkout |
| Plan selection cards | ✅ | |
| Subscription status display | ✅ | Active/pending/halted |
| Expiry date shown | ✅ | In profile + subscription screen |
| Grace period UI | 🔶 | `graceUntil` in model but not displayed |
| Cancellation UI | ⬜ | No way for user to cancel |
| Renewal prompt | ⬜ | No flow for expired subscriptions |

---

## Page Viewer
| Feature | Status | Notes |
|---------|--------|-------|
| PageView with swipe | ✅ | |
| Pinch-to-zoom (1x–5x) | ✅ | `InteractiveViewer` |
| Double-tap zoom (with animation) | ✅ | `Matrix4Tween`, tap-centered |
| Page preloading | ✅ | Batch of 4 initial, 3 ahead |
| Animated page transitions | ✅ | Fade + slide + scale |
| Page number indicator | ✅ | `AnimatedSwitcher` |
| Screenshot blocking | ✅ | `screen_protector` |
| Watermark overlay | ✅ | Obfuscated user email |
| Gatekeeper API (paywall) | ✅ | 402 if no subscription |

---

## Offline Downloads
| Feature | Status | Notes |
|---------|--------|-------|
| Batch download (3 parallel) | ✅ | |
| Download progress polling | ✅ | 500ms interval |
| Individual chapter delete | ✅ | |
| Clear all downloads | ✅ | |
| Storage usage display | ✅ | Per chapter + total |
| Downloads tab in bottom nav | ✅ | New tab added |
| Navigate from downloads → viewer | 🔶 | Needs `ContentModel` from cache metadata |
| Background download notification | ⬜ | Not implemented |

---

## Encrypted Cache
| Feature | Status | Notes |
|---------|--------|-------|
| XOR encryption with device key | ✅ | `flutter_secure_storage` (Keystore/Keychain) |
| Atomic writes (`.tmp` → rename) | ✅ | Prevents corruption |
| Per-file locking | ✅ | `Map<String, bool> _fileLocks` |
| Persistent cache (app docs dir) | ✅ | Not wiped by OS |
| Key invalidation on logout | ✅ | Format v2 |
| Cache format versioning | ✅ | `[PNC][version][data]` |

---

## Profile
| Feature | Status | Notes |
|---------|--------|-------|
| Profile header (name, email, roll) | ✅ | |
| Subscription card | ✅ | Active status + expiry |
| Bookmarks section | ✅ | Shows last 5 |
| Edit name/roll/phone | 🔶 | Repository methods exist, no UI |
| Device list | 🔶 | Queried but not displayed |

---

## Notices System
| Feature | Status | Notes |
|---------|--------|-------|
| Info notices (dismissable dialog) | ✅ | |
| Urgent notices (non-dismissable) | ✅ | |
| Update notices (with link + force) | ✅ | |
| Version-aware filtering | ✅ | `minAppVersion` / `maxAppVersion` |
| Sequential display on launch | ✅ | |
| Periodic re-fetch on resume | ✅ | |
| Priority ordering | ✅ | |

---

## Admin Dashboard
| Feature | Status | Notes |
|---------|--------|-------|
| Token-based auth | ✅ | |
| Content table with sort/search/filter | ✅ | |
| PDF upload with client-side conversion | ✅ | pdf.js → JPEG → base64 upload |
| Single delete | ✅ | |
| Delete all with confirmation | ✅ | Double confirm |
| Content stats (total, R2, size) | ✅ | |
| Notices CRUD tab | ✅ | Create/edit/delete |
| Notice type/status filters | ✅ | |
| Scheduled notices (starts_at/expires_at) | ✅ | |
| User management | ⬜ | Not implemented |
| Analytics | ⬜ | Not implemented |

---

## Technical
| Feature | Status | Notes |
|---------|--------|-------|
| Riverpod state management | ✅ | StateNotifier + FutureProvider |
| Supabase backend | ✅ | Auth, DB, Edge Functions |
| Cloudflare R2 storage | ✅ | Page images |
| Razorpay LIVE payments | ✅ | Production keys configured |
| Offline-first browsing | ✅ | SharedPreferences cache |
| Device-bound encryption | ✅ | Key tied to device, not session |
| GoRouter | ⬜ | Declared in pubspec, not used |
| Tests | ⬜ | No test files exist |
| Dark mode | ⬜ | Light theme only |

---

## Next Up

1. **Download → Viewer navigation** — store minimal `ContentModel` metadata alongside cached chapters so tapping a downloaded chapter opens the viewer
2. **Profile editing UI** — add edit button/modal for name, roll number, phone
3. **Grace period display** — show `graceUntil` in subscription card
4. **Subscription cancellation** — API call to cancel Razorpay subscription
5. **User management in admin** — view/search/disable users
6. **Admin content search by chapter** — add chapter name search
