# Avatar, Daily Quotes, and UI Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add server-synced optional contact avatars, user-specific daily quotes from the supplied 500-quote document, the signed-in nickname in the relationship-map center, and a smaller, cleaner navigation treatment.

**Architecture:** The backend owns avatar validation, local filesystem storage, ownership checks, and media serving while continuing to store only `avatar_url` on contacts. The iOS app uses `PhotosPicker`, uploads compressed JPEG data after contact creation, loads remote images with a fallback avatar, and reads a bundled JSON quote catalog using a deterministic user-and-date selector. Shared theme components are simplified so decorative rules disappear globally without removing functional separators.

**Tech Stack:** SwiftUI, PhotosUI, URLSession multipart upload, FastAPI, SQLAlchemy async, pytest/httpx, bundled JSON resources, Swift Testing.

## Global Constraints

- Do not use subagents; execute this plan inline in the current task.
- Avatar selection is optional and uses the photo library only.
- Avatar files are stored locally under `SoulMark_backend/uploads/avatars`; the storage service must remain replaceable by OSS later.
- Only authenticated owners may upload, replace, or delete a contact avatar.
- Daily quote selection is stable for one user during one local calendar day and changes with the date.
- The quote source is visually secondary to the quote text.
- Remove decorative rules only; retain functional dividers, borders, relationship lines, and selection indicators.
- Preserve the five existing bottom navigation destinations.

---

### Task 1: Extract and Bundle the 500-Quote Catalog

**Files:**
- Create: `SoulMark/DailyQuotes.json`
- Create: `SoulMark/DailyQuotes.swift`
- Modify: `SoulMark/SoulModels.swift`
- Modify: `SoulMark/HomeProfileViews.swift`
- Modify: `SoulMark/ContentView.swift`
- Modify: `SoulMarkTests/SoulMarkTests.swift`

**Interfaces:**
- Produces: `DailySoulQuote`, `DailyQuoteCatalog.load(bundle:)`, and `DailyQuoteCatalog.quote(userID:date:calendar:)`.
- Consumes: `AppSession.user?.id`, current app language, and the bundled `DailyQuotes.json` resource.

- [ ] **Step 1: Generate the JSON catalog from the supplied DOCX**

Use the bundled Python runtime and `python-docx` to parse repeating English, `中文：`, and `Source / 出处：` paragraphs from:

```text
/Users/yangzirui/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/wxid_3av2qp616lon12_062a/temp/drag/500_Authentic_Quotes_English_Chinese_Sourced.docx
```

Write an array of exactly 500 objects shaped as:

```json
{
  "id": 1,
  "english": "A journey of a thousand miles begins with a single step.",
  "chinese": "千里之行，始于足下。",
  "source": "Laozi, Tao Te Ching (traditional translation)"
}
```

Strip numeric prefixes and outer quotation marks while preserving punctuation inside the quotation.

- [ ] **Step 2: Write failing quote-catalog tests**

Add Swift Testing cases that assert:

```swift
let quotes = try DailyQuoteCatalog.load()
#expect(quotes.count == 500)
#expect(quotes.allSatisfy { !$0.chinese.isEmpty && !$0.english.isEmpty && !$0.source.isEmpty })

let first = DailyQuoteCatalog.quote(userID: fixedUserID, date: morning, calendar: calendar)
let repeated = DailyQuoteCatalog.quote(userID: fixedUserID, date: evening, calendar: calendar)
#expect(first == repeated)
#expect(first.source.isEmpty == false)
```

Also verify the next local date yields the deterministic result calculated by the selector rather than relying on random runtime state.

- [ ] **Step 3: Run the tests and confirm they fail**

Run:

```bash
xcodebuild test -project SoulMark.xcodeproj -scheme SoulMark -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Expected: compilation fails because `DailyQuoteCatalog` does not exist.

- [ ] **Step 4: Implement the catalog and deterministic selector**

Move `DailySoulQuote` into `DailyQuotes.swift`, add `source`, and decode the bundled JSON. Derive a stable unsigned hash from the UUID bytes plus a `yyyy-MM-dd` local date string using an explicit deterministic algorithm such as FNV-1a; never use Swift `Hasher`, whose seed changes between launches. Select `hash % quotes.count`. Keep six fallback quotes in code for bundle-decoding failure.

Update the home page to call:

```swift
DailyQuoteCatalog.quote(userID: userID ?? DailyQuoteCatalog.guestUserID)
```

Display `quote.source` below the body using a 9–10 point semibold font and tertiary text color. Include the source in `shareText`.

- [ ] **Step 5: Pass the signed-in user ID to the home page**

Add `userID: UUID?` to `IntegratedHomePage` and pass `session.user?.id` from `ContentView` so quote selection is user-specific.

- [ ] **Step 6: Run quote tests**

Run the focused Swift test target and confirm all catalog tests pass with exactly 500 decoded records.

- [ ] **Step 7: Commit**

```bash
git add SoulMark/DailyQuotes.json SoulMark/DailyQuotes.swift SoulMark/SoulModels.swift SoulMark/HomeProfileViews.swift SoulMark/ContentView.swift SoulMarkTests/SoulMarkTests.swift
git commit -m "feat: add user-specific daily quote catalog"
```

---

### Task 2: Add Secure Backend Avatar Storage and Endpoints

**Files:**
- Create: `SoulMark_backend/app/services/avatar_storage.py`
- Modify: `SoulMark_backend/app/api/v1/contacts.py`
- Modify: `SoulMark_backend/app/services/contacts.py`
- Modify: `SoulMark_backend/app/core/config.py`
- Modify: `SoulMark_backend/app/main.py`
- Modify: `SoulMark_backend/pyproject.toml`
- Modify: `SoulMark_backend/tests/test_contacts.py`

**Interfaces:**
- Produces: `POST /api/v1/contacts/{contact_id}/avatar`, `DELETE /api/v1/contacts/{contact_id}/avatar`, and `/media/avatars/{filename}`.
- Consumes: existing `Contact.avatar_url`, authenticated `CurrentUser`, and `get_owned_contact`.

- [ ] **Step 1: Write failing backend avatar tests**

Add tests using multipart files:

```python
uploaded = await client.post(
    f"/api/v1/contacts/{contact_id}/avatar",
    headers=auth_headers,
    files={"file": ("avatar.jpg", jpeg_bytes, "image/jpeg")},
)
assert uploaded.status_code == 200
assert uploaded.json()["avatar_url"].startswith("/media/avatars/")
```

Cover replacement removing the prior file, deletion setting `avatar_url` to `None`, unsupported MIME returning `400 invalid_avatar_type`, oversized input returning `413 avatar_too_large`, another user receiving `404 contact_not_found`, and deleting a contact removing its avatar file.

- [ ] **Step 2: Run focused backend tests and confirm failure**

Run:

```bash
cd SoulMark_backend && uv run pytest -q tests/test_contacts.py
```

Expected: avatar routes return 404.

- [ ] **Step 3: Implement the storage service**

Add an `AvatarStorage` service configured from:

```python
avatar_upload_dir: Path = Path("uploads/avatars")
avatar_max_bytes: int = 5 * 1024 * 1024
```

Accept `image/jpeg`, `image/png`, and `image/heic`; read at most `max + 1` bytes; validate actual image content with Pillow; normalize to RGB JPEG; cap dimensions at 1024×1024; save atomically under a UUID filename. Return a relative `/media/avatars/<uuid>.jpg` URL. Resolve deletion only inside the configured avatar directory to prevent path traversal.

- [ ] **Step 4: Add authenticated endpoints and media mounting**

Use `UploadFile` and `File`, call `get_owned_contact` before touching storage, update `contact.avatar_url`, commit, and return `ContactResponse`. Mount the parent media directory with FastAPI `StaticFiles` at `/media` in `main.py` after ensuring the directory exists.

- [ ] **Step 5: Clean avatars during contact deletion**

Inject or call the storage cleanup before deleting the database contact. Missing old files must be tolerated so database deletion still succeeds.

- [ ] **Step 6: Run backend verification**

Run:

```bash
cd SoulMark_backend && uv run pytest -q tests/test_contacts.py && uv run ruff check app tests && uv run mypy app
```

- [ ] **Step 7: Commit**

```bash
git add SoulMark_backend/app SoulMark_backend/tests/test_contacts.py SoulMark_backend/pyproject.toml SoulMark_backend/uv.lock SoulMark_backend/requirements.txt
git commit -m "feat: add contact avatar upload storage"
```

---

### Task 3: Add iOS Avatar Data and Networking

**Files:**
- Create: `SoulMark/ContactAvatar.swift`
- Modify: `SoulMark/AppSession.swift`
- Modify: `SoulMark/SoulModels.swift`
- Modify: `SoulMarkTests/SoulMarkTests.swift`

**Interfaces:**
- Produces: `RelationshipPerson.avatarURL`, `AppSession.uploadContactAvatar(contactID:imageData:)`, `AppSession.deleteContactAvatar(contactID:)`, and a reusable remote/fallback avatar view.
- Consumes: backend relative `avatar_url`, stored backend base URL, and bearer token.

- [ ] **Step 1: Write failing model and URL tests**

Test that a contact response containing `/media/avatars/example.jpg` maps to `RelationshipPerson.avatarURL`, and that `SoulAPIClient` resolves it against the configured base URL without duplicating or dropping paths.

- [ ] **Step 2: Run tests and confirm failure**

Run the iOS test target; expect compilation failure for missing avatar APIs.

- [ ] **Step 3: Extend contact models**

Add optional `avatarURL: String?` to `RemoteContact`, `ContactPayload`, and `RelationshipPerson`. Preserve it through category and position updates. Keep sample people and newly added people at `nil`.

- [ ] **Step 4: Implement multipart upload and deletion**

Build a multipart request containing JPEG bytes under field `file`, apply `Authorization: Bearer <token>`, and decode the updated `RemoteContact`. Add a DELETE request for the avatar endpoint. Reuse a single base-URL resolver so API and media URLs both respect the saved backend address.

- [ ] **Step 5: Implement reusable avatar rendering**

In `ContactAvatar.swift`, use `AsyncImage` for a resolved remote URL and show the existing category/SF Symbol avatar while loading or on failure. Clip to a circle and retain the existing border treatment.

- [ ] **Step 6: Run iOS tests and commit**

```bash
git add SoulMark/ContactAvatar.swift SoulMark/AppSession.swift SoulMark/SoulModels.swift SoulMarkTests/SoulMarkTests.swift
git commit -m "feat: connect iOS contact avatars"
```

---

### Task 4: Add Avatar Selection to Contact Creation and Details

**Files:**
- Modify: `SoulMark/RelationshipGraphViews.swift`
- Modify: `SoulMark/ContentView.swift`
- Modify: `SoulMark/ContactAvatar.swift`

**Interfaces:**
- Consumes: `PhotosPickerItem`, `AppSession` avatar methods, and `RelationshipPerson.avatarURL`.
- Produces: optional avatar selection during add and add/change/remove actions in contact details.

- [ ] **Step 1: Add image preparation helpers with tests where possible**

Load transferable `Data`, decode to `UIImage`, center-crop to square, resize to at most 1024×1024, and export JPEG at 0.82 quality. Reject data that cannot decode as an image.

- [ ] **Step 2: Update AddPersonSheet**

Add a circular preview and `PhotosPicker` labeled “添加头像（可跳过） / Add photo (optional)”. Change the callback to return prepared optional JPEG data:

```swift
let onAdd: (String, String, RelationshipCategory, Data?) -> Void
```

Create the contact first, then upload the image using the remote contact ID. If upload fails, keep the contact with its fallback avatar and expose a non-blocking error message.

- [ ] **Step 3: Update RelationshipDetailSheet**

Replace `ProfileAvatarView` with the reusable avatar. Add a photo picker action and, when an avatar exists, a destructive “删除头像 / Remove Photo” action. Return updated contacts to `ContentView` so both the sheet and graph refresh immediately.

- [ ] **Step 4: Update relationship graph nodes**

Render real avatars in `RelationshipNode`; keep the category icon fallback unchanged.

- [ ] **Step 5: Build and manually verify on iPhone**

Verify skip, upload, replace, remove, relaunch persistence, offline fallback, and that choosing a large photo does not freeze the main thread.

- [ ] **Step 6: Commit**

```bash
git add SoulMark/RelationshipGraphViews.swift SoulMark/ContentView.swift SoulMark/ContactAvatar.swift
git commit -m "feat: add contact avatar editing UI"
```

---

### Task 5: Bind the Relationship Center to the Signed-In Nickname

**Files:**
- Modify: `SoulMark/ContentView.swift`
- Modify: `SoulMark/RelationshipGraphViews.swift`
- Modify: `SoulMarkTests/SoulMarkTests.swift`

**Interfaces:**
- Consumes: `session.user?.displayName`.
- Produces: `RelationshipMapView(ownerDisplayName:)` and `CenterProfile(displayName:)`.

- [ ] **Step 1: Add a nickname normalization test**

Verify whitespace-only names become localized “我 / Me” and long names remain a single display value suitable for line limiting.

- [ ] **Step 2: Pass and render the nickname**

Pass `session.user?.displayName` from `ContentView`, trim whitespace, and use the fallback when empty. Replace `Text("Elias")` with the supplied display name, adding `.lineLimit(1)` and `.minimumScaleFactor(0.55)` inside a bounded width.

- [ ] **Step 3: Run iOS tests and commit**

```bash
git add SoulMark/ContentView.swift SoulMark/RelationshipGraphViews.swift SoulMarkTests/SoulMarkTests.swift
git commit -m "feat: show user nickname in relationship map"
```

---

### Task 6: Reduce the Bottom Navigation and Remove Decorative Rules

**Files:**
- Modify: `SoulMark/AppTabBar.swift`
- Modify: `SoulMark/SoulTheme.swift`
- Modify: `SoulMark/HomeProfileViews.swift`
- Modify: any page file still containing the identified decorative two-capsule motif.

**Interfaces:**
- Preserves: all five `AppSection` destinations, selected state, functional dividers, borders, and relationship lines.
- Produces: smaller navigation geometry and simplified shared backgrounds.

- [ ] **Step 1: Remove shared decorative rule implementations**

Delete the top-left two-capsule overlay from `SoulBackground`, the accented top rule from `SoulGlassCardBackground`, and the two-capsule rule from `SoulVisorPanelBackground`. Keep the `accented` parameter temporarily only if call sites still require source compatibility, otherwise remove it and update callers.

- [ ] **Step 2: Remove navigation-only decorative rules**

Delete the top white capsule overlay on `AppTabBar` and the small energy capsule inside the primary simulation tab. Preserve selected backgrounds and strokes.

- [ ] **Step 3: Apply compact navigation geometry**

Set the outer height to 68 points, horizontal margin to 22 points, bottom margin to 12 points, reduce inner vertical padding, use approximately 17-point regular icons and a 44×40 primary button, and retain accessible button hit areas of at least 44×44 points.

- [ ] **Step 4: Search for remaining decorative motifs**

Run:

```bash
rg -n -U 'HStack\(spacing: 5\).*Capsule|overlay\(alignment: \.top|frame\(width: (44|48|58), height: (2|3)\)' SoulMark -g '*.swift'
```

Inspect each match and remove only non-functional ornamentation.

- [ ] **Step 5: Build and visually inspect all five pages**

Verify the bottom corners have visible breathing room on the smallest supported iPhone, all five labels fit, selected states remain clear, and functional separators remain intact.

- [ ] **Step 6: Commit**

```bash
git add SoulMark/AppTabBar.swift SoulMark/SoulTheme.swift SoulMark/HomeProfileViews.swift SoulMark/*.swift
git commit -m "style: simplify navigation and decorative chrome"
```

---

### Task 7: Full Regression Verification and Documentation

**Files:**
- Modify: `SoulMark_backend/README.md`
- Modify: `.gitignore`

**Interfaces:**
- Documents: avatar directory behavior and production persistent-storage requirement.
- Protects: uploaded runtime files from Git tracking.

- [ ] **Step 1: Ignore uploaded runtime content**

Add `SoulMark_backend/uploads/` to `.gitignore`, while allowing the application to create directories at startup.

- [ ] **Step 2: Document avatar storage**

Explain the 5 MB limit, supported image formats, local development location, and that production deployments require persistent storage or an OSS-backed implementation.

- [ ] **Step 3: Run complete backend verification**

```bash
cd SoulMark_backend
uv run pytest -q
uv run ruff format --check app tests
uv run ruff check app tests
uv run mypy app
uv run alembic heads
```

Expected: all tests and checks pass; Alembic reports one head.

- [ ] **Step 4: Run complete iOS verification**

```bash
xcodebuild test -project SoulMark.xcodeproj -scheme SoulMark -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

If that simulator runtime is unavailable, use an installed iOS simulator shown by `xcrun simctl list devices available` and record the chosen destination.

- [ ] **Step 5: Perform true-device acceptance checks**

Start the backend on `0.0.0.0:8000`, verify `/health/ready`, then confirm on iPhone: registration remains valid, existing contacts load, add contact with and without an avatar, replace/delete avatar, nickname appears at the map center, the quote remains stable across relaunch, and all five pages have the compact navigation and no decorative rules.

- [ ] **Step 6: Commit final documentation**

```bash
git add .gitignore SoulMark_backend/README.md
git commit -m "docs: document avatar media storage"
```
