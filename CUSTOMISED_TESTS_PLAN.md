# Customised Tests System — Implementation Plan

## Overview

Admin uploads Word docs (.docx) with MCQs → questions parsed client-side → users take timed tests inside each subject → weekly leaderboard.

---

## 1. Database Schema (Supabase Migration)

### New Storage Bucket
- **Bucket name:** `test-images`
- **Visibility:** Public (images need to load in app)
- **RLS:** authenticated can upload, anyone can read
- **Path structure:** `test-images/{test_id}/{filename}`

### `tests` table
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | Auto-generated |
| `subject_id` | UUID FK→subjects | Which subject this test belongs to |
| `title` | text | e.g. "Unit 1 Mock Test" |
| `description` | text nullable | Optional instructions |
| `time_limit_minutes` | integer | e.g. 30 |
| `marks_per_question` | integer | e.g. 4 |
| `is_active` | boolean | default true |
| `created_at` | timestamp | default now() |

### `test_questions` table
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | Auto-generated |
| `test_id` | UUID FK→tests | |
| `question_index` | integer | Order (1, 2, 3...) |
| `question` | text | The question text |
| `options` | jsonb | Array of 4 strings: ["A text","B text","C text","D text"] |
| `correct_answer` | text | "A", "B", "C", or "D" |
| `marks` | integer | Marks for this question |
| `image_urls` | jsonb nullable | Array of image URLs for this question |

### `test_submissions` table
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | Auto-generated |
| `test_id` | UUID FK→tests | |
| `user_id` | UUID FK→auth.users | |
| `started_at` | timestamp | When user started |
| `submitted_at` | timestamp nullable | When user submitted |
| `score` | integer | Total marks earned |
| `total_marks` | integer | Total possible marks |
| `is_completed` | boolean | default false |

### `test_answers` table
| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | Auto-generated |
| `submission_id` | UUID FK→test_submissions | |
| `question_id` | UUID FK→test_questions | |
| `selected_answer` | text nullable | "A"/"B"/"C"/"D" or null if skipped |
| `is_correct` | boolean | |
| `marks_earned` | integer | default 0 |

### RLS Policies
- `tests`: authenticated can read, service-role can do everything
- `test_questions`: authenticated can read, service-role can do everything
- `test_submissions`: authenticated can insert (own user_id), read (own), service-role full
- `test_answers`: authenticated can insert (own submission), read (own), service-role full

---

## 2. Word Doc Format (MCQ)

Admin creates a .docx file in this exact format:

### Text-only questions
```
1. What is 2+2?
A. 3
B. 4
C. 5
D. 6
Answer: B

2. Capital of France?
A. London
B. Paris
C. Berlin
D. Madrid
Answer: B
```

### Questions with images
```
3. Which circuit diagram shows a parallel connection?
[IMG:parallel_circuit.png]
A. Series circuit
B. Parallel circuit
C. Mixed circuit
D. None of these
Answer: B

4. Identify the organ labeled X.
[IMG:anatomy_diagram.png]
A. Heart
B. Liver
C. Kidney
D. Lung
Answer: C
```

### Image Rules
- Use `[IMG:filename.png]` placeholder in the question text (anywhere — before options, after options, or between)
- The actual image must be inserted in the Word doc (so it's embedded in the .docx file)
- Parser extracts images from the .docx's internal `word/media/` folder
- Images are uploaded to Supabase Storage bucket `test-images/{test_id}/`
- Question stores URLs in `image_urls` JSONB array
- Multiple images per question supported: `[IMG:img1.png]` and `[IMG:img2.png]`
- Supported formats: PNG, JPG/JPEG, GIF, SVG (convert SVG to PNG in .docx for best results)
- Max recommended image size: 1MB each (compressed automatically by Word)

### Rules
- Questions start with a number + dot (`1.` `2.` etc.)
- Options are `A.` `B.` `C.` `D.` (case-insensitive, with or without dot)
- Answer line is `Answer: X` where X is A/B/C/D
- Blank lines between questions (optional, parser handles both)
- No other formatting needed — plain text only

---

## 3. Docx Parser

### Package
`docx` (pub.dev) — pure Dart, no native dependencies

### Parser Logic (`lib/features/test/data/docx_parser.dart`)

**Text extraction:**
1. Read .docx file bytes
2. Extract text from all paragraphs
3. Join paragraphs into a single string
4. Split on numbered question pattern: `(?=\d+\.\s)`
5. For each question block:
   - Extract question text (everything before first option)
   - Detect `[IMG:filename]` placeholders in question text
   - Extract A/B/C/D options
   - Extract answer from `Answer:` line
6. Return `List<ParsedQuestion>`

**Image extraction:**
1. Unzip .docx (it's a ZIP archive — use `archive` package)
2. Read `word/media/` folder contents
3. Match filenames to `[IMG:filename]` placeholders found in questions
4. Extract image bytes for each matched image
5. Return alongside question data

### ParsedQuestion class
```dart
class ParsedQuestion {
  final String question;        // text with [IMG:filename] placeholders
  final List<String> options;   // length 4
  final String correctAnswer;   // "A"/"B"/"C"/"D"
  final List<ParsedImage> images; // extracted images from docx
}

class ParsedImage {
  final String filename;   // original filename from docx
  final List<int> bytes;   // raw image bytes
  final String mimeType;   // "image/png", "image/jpeg", etc.
}
```

### Image Upload Flow
1. `TestRepository.createTest()` receives parsed questions + images
2. For each question with images:
   - Upload image bytes to Supabase Storage: `test-images/{test_id}/{filename}`
   - Get public URL
   - Store URL in `image_urls` JSONB array on the question row
3. Replace `[IMG:filename]` with `[IMG:0]`, `[IMG:1]` etc. (index-based) for cleaner rendering

---

## 4. Data Models

### `lib/features/test/data/models/test_model.dart`
```dart
class TestModel {
  final String id;
  final String subjectId;
  final String title;
  final String? description;
  final int timeLimitMinutes;
  final int marksPerQuestion;
  final bool isActive;
  final DateTime createdAt;
  int? questionCount; // populated from join
}
```

### `lib/features/test/data/models/test_question_model.dart`
```dart
class TestQuestion {
  final String id;
  final String testId;
  final int questionIndex;
  final String question;
  final List<String> options; // 4 items
  final String correctAnswer;
  final int marks;
}
```

### `lib/features/test/data/models/test_submission_model.dart`
```dart
class TestSubmission {
  final String id;
  final String testId;
  final String userId;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final int score;
  final int totalMarks;
  final bool isCompleted;
}
```

---

## 5. Test Repository

### `lib/features/test/data/test_repository.dart`

```dart
class TestRepository {
  final _sb = Supabase.instance.client;

  // Fetch active tests for a subject
  Future<List<TestModel>> getTestsForSubject(String subjectId);

  // Parse .docx file on device
  Future<List<ParsedQuestion>> parseDocxFile(File file);

  // Admin: create test + questions
  Future<void> createTest({
    required String subjectId,
    required String title,
    String? description,
    required int timeLimitMinutes,
    required int marksPerQuestion,
    required List<ParsedQuestion> questions,
  });

  // User: start a test (creates submission row)
  Future<TestSubmission> startTest(String testId);

  // User: submit answers
  Future<TestSubmission> submitTest({
    required String submissionId,
    required Map<String, String?> answers, // questionId → selected answer
  });

  // Leaderboard: current week (Mon–Sun)
  Future<List<LeaderboardEntry>> getLeaderboard();

  // User's past submissions for a test
  Future<List<TestSubmission>> getUserSubmissions(String testId, String userId);
}
```

---

## 6. Providers

### `test_list_provider.dart`
```dart
// Fetches tests for a given subject
final testsForSubjectProvider = FutureProvider.family<List<TestModel>, String>((ref, subjectId) async {
  return TestRepository().getTestsForSubject(subjectId);
});
```

### `test_taking_provider.dart`
```dart
// Manages active test state
class TestTakingState {
  final TestModel test;
  final List<TestQuestion> questions;
  final int currentIndex;
  final Map<String, String?> answers; // questionId → selected
  final int remainingSeconds;
  final bool isSubmitted;
}

class TestTakingNotifier extends StateNotifier<TestTakingState> {
  // Methods: selectAnswer, nextQuestion, previousQuestion, submit, tick (timer)
}
```

### `leaderboard_provider.dart`
```dart
final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  return TestRepository().getLeaderboard();
});
```

---

## 7. App Screens

### A. Test List (inside subject section in Browse)
- Shows as a "📝 Available Tests" divider below chapter cards
- Each test card shows: title, time limit, marks per question, question count
- Tap → navigates to Test Detail screen

### B. Test Detail Screen
- Test title, description/instructions
- Time limit display
- Total marks = questionCount × marksPerQuestion
- "Start Test" button (green, prominent)
- Past attempts section (if any, shows score and date)

### C. Test Taking Screen (full-screen, timed)
- **Top bar:** countdown timer (MM:SS), turns red when < 2 min
- **Middle:** question card with question text + images + 4 option buttons
- **Bottom:** Previous / Next / Submit buttons
- Options are radio-style cards (tap to select, highlight in amber)
- Swipe or tap to navigate between questions
- **Auto-submit** when timer hits 0
- **Submit confirmation** dialog: "You attempted X out of Y. Submit?"
- Back button blocked (or shows warning)

### Image Rendering in Questions
```dart
// question_card.dart — renders text + inline images
Widget buildQuestionText(String text, List<String>? imageUrls) {
  // Split text on [IMG:0], [IMG:1] etc. placeholders
  // Between text spans, insert Image.network() widgets
  // Example: "Which circuit is correct?" → Image → "A. Series..."
}
```
- Images load from Supabase Storage URLs
- Shown full-width within the question card
- Tappable to zoom (optional enhancement)
- Loading spinner while images load

### D. Test Result Screen
- Big score display: "18 / 24 marks"
- Percentage: "75%"
- Breakdown: Correct (12) | Incorrect (4) | Skipped (4)
- "Review Answers" expandable section:
  - Each question shows: your answer, correct answer, marks earned
  - Green check for correct, red X for incorrect
- "View Leaderboard" button
- "Back to Tests" button

### E. Leaderboard Screen
- Header: "Weekly Leaderboard" with date range (e.g. "Jul 28 – Aug 3")
- Top 3 highlighted with gold/silver/bronze styling
- List: Rank | User Name | Total Marks | Tests Taken
- Current user's row highlighted in amber
- Pull to refresh
- Empty state if no submissions this week

---

## 8. Browse Screen Integration

In `browse_screen.dart` `_buildSubjectSection()`:

```dart
Widget _buildSubjectSection(String subject, List<ContentModel> chapters) {
  // Existing chapter cards...

  // Add tests section below chapters
  return Column(
    children: [
      // ... existing subject header + chapter cards ...

      // Tests divider + cards
      _buildTestsSection(subject),
    ],
  );
}

Widget _buildTestsSection(String subjectName) {
  // Look up subject_id from subjects table by name
  // Fetch tests for that subject_id
  // Show test cards if any exist
}
```

The test cards in Browse:
- Distinct styling: amber/orange icon instead of blue
- Show: title, ⏱ time limit, 📝 marks per question
- Tap → Test Detail screen

---

## 9. Admin Dashboard Updates

### In `courses.html` — Tests virtual folder
When clicking "Tests" in a subject, show existing tests + "Create Test" button.

### Create Test Flow
1. Click "Create Test" in admin
2. Modal opens with:
   - Test title input
   - Time limit (minutes) input
   - Marks per question input
   - File upload zone (accepts .docx only)
3. Upload .docx → parse client-side → show preview of extracted questions
4. Admin can edit/delete individual questions
5. Click "Save Test" → inserts to `tests` + `test_questions` tables

---

## 10. File Structure

```
lib/features/test/
  data/
    docx_parser.dart
    image_extractor.dart      # extracts images from .docx ZIP
    test_repository.dart
    storage_repository.dart   # uploads images to Supabase Storage
    models/
      test_model.dart
      test_question_model.dart
      test_submission_model.dart
      leaderboard_entry.dart
      parsed_question.dart    # includes ParsedImage
  presentation/
    providers/
      test_list_provider.dart
      test_taking_provider.dart
      leaderboard_provider.dart
    screens/
      test_detail_screen.dart
      test_taking_screen.dart
      test_result_screen.dart
      leaderboard_screen.dart
    widgets/
      test_card.dart
      question_card.dart      # renders text + inline images
      timer_countdown.dart
      leaderboard_tile.dart
      option_button.dart
```

---

## 11. Build Order

| Step | What | Depends On |
|---|---|---|
| 1 | Supabase migration (4 tables + RLS + storage bucket) | Nothing |
| 2 | Add `docx` to pubspec.yaml | Nothing |
| 3 | Data models (test, question, submission) | Step 1 |
| 4 | Docx parser (text + image extraction) + test it | Steps 2, 3 |
| 5 | Test repository | Steps 1, 3 |
| 6 | Providers | Step 5 |
| 7 | Test detail screen | Step 6 |
| 8 | Test taking screen (timer + questions) | Step 6 |
| 9 | Test result screen | Step 6 |
| 10 | Leaderboard screen | Step 6 |
| 11 | Browse screen integration (test cards) | Steps 6, 10 |
| 12 | Admin dashboard — create test UI | Steps 4, 5 |

---

## 12. Dependencies to Add

```yaml
# pubspec.yaml
dependencies:
  docx: ^1.0.0        # Word doc text extraction
  archive: ^3.0.0     # Unzip .docx to extract embedded images
```

---

## 13. Key Design Decisions

1. **Client-side parsing** — no Edge Function needed, works offline for parsing
2. **Tests linked to subjects** — matches existing admin hierarchy
3. **Weekly leaderboard** — resets every Monday 00:00 UTC
4. **Auto-submit on timer expiry** — prevents cheating
5. **One active submission per test per user** — can't start same test twice
6. **Review after submit** — users see correct answers only after submission
7. **No question randomization** (v1) — all users see same order, can add later

---

## 14. Future Enhancements (Not in v1)

- Question randomization per user
- Shuffle option order
- Negative marking
- Export leaderboard as CSV
- Test history analytics for admin
- Question categories/tags
- Practice mode (no timer, instant feedback)
