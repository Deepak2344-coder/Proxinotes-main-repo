# Desktop Folder System — Changelog

Track all changes for the admin dashboard desktop-like folder organization feature.
If we need to revert, reverse these changes in order.

---

## 2026-07-31 — Initial Implementation

### New Files Created
- `CHANGELOG.md` — This file
- `E:\Notes-distribution-system\supabase\migrations\0007_course_folders.sql` — Database migration for 5 new tables
- `E:\NotesApp\admin\courses.html` — Desktop-like folder admin UI (1552 lines, standalone page)

### Modified Files
- `E:\NotesApp\admin\index.html` — Added "Open Course Manager" button in header

### Database Changes (Migration 0007 — applied to Supabase)
New tables:
1. `courses` — Top-level course folders (name, description, price, specs, terms)
2. `subjects` — Subject folders within courses (with order_index)
3. `units` — Unit subfolders within subjects (with order_index)
4. `files` — PDF files (study_material, test_pdf, assignment_pdf, question_bank)
5. `questions` — Individual questions (mcq, short, long answer)

All tables have RLS enabled with service-role full access + authenticated read access.

### courses.html Features
- Token-based login (UI gate, service role key used for API)
- Sidebar tree view (courses → subjects, collapsible)
- Breadcrumb navigation (clickable path segments)
- Grid view with folder/file/question cards
- Right-click context menus (create, rename, upload, delete)
- Modals: Create/Edit Course, Create Subject, Rename, Create Unit, Upload File, Create/Edit Question, Delete confirmation
- PDF drop zone with pdf.js page count detection
- All CRUD via Supabase REST API
- Toast notifications, keyboard shortcuts (Escape)

### Fixes Applied
- sbGet returns `[]` on error (not `{ error: ... }`) for safe array usage
- sbHeaders uses service role key (matching existing admin dashboard pattern)
- Login is UI gate only (no API auth check needed with service role key)
- Removed dead `HEADERS` constant

### Revert Steps
1. Run in Supabase SQL Editor: `DROP TABLE IF EXISTS questions, files, units, subjects, courses CASCADE;`
2. Delete `E:\NotesApp\admin\courses.html`
3. Remove "Open Course Manager" button from `E:\NotesApp\admin\index.html`
4. Delete `E:\NotesApp\CHANGELOG.md`
5. Delete `E:\Notes-distribution-system\supabase\migrations\0007_course_folders.sql`
