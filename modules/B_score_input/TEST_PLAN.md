# Module B: Score Input & Library - Test Plan

## Test Infrastructure
- **Test Framework**: Flutter test (unit) + local SQLite test database
- **Setup**: Each test uses fresh SQLite database in memory or temp directory
- **Teardown**: Delete all created scores, close DB connections, delete temp files
- **Timeout**: 5 seconds per test (adjust for I/O-heavy tests to 10s)

---

## Unit Tests: importPdf()

### T-B-PDF-001: Valid single-page PDF
**Setup**: Create valid PDF with 1 page (standard music notation background)
**Command**: `importPdf("/path/to/single.pdf")`
**Assertions**:
- Return is `{ ok: true, value: ScoreEntry }`
- ScoreEntry.id is valid UUID
- ScoreEntry.sourceType == "pdf"
- ScoreEntry.versions contains "original_image" key
- File written to `versions/{id}/original_image_*.png`
- File is valid PNG (magic bytes: 89 50 4E 47)

### T-B-PDF-002: Valid multi-page PDF
**Setup**: Create PDF with 5 pages
**Command**: `importPdf("/path/to/multi.pdf")`
**Assertions**:
- Return is `{ ok: true, value: ScoreEntry }`
- ScoreEntry.versions["original_image"].metadata.pageCount == 5
- 5 PNG files created (or 1 composite, implementation-dependent)
- All PNG files readable and valid

### T-B-PDF-003: PDF with maximum pages (500)
**Setup**: Generate PDF with 500 blank pages
**Command**: `importPdf("/path/to/large.pdf")`
**Assertions**:
- Import completes within 30 seconds
- ScoreEntry created successfully
- All 500 pages processed

### T-B-PDF-004: Corrupted PDF
**Setup**: File with `%PDF-` header but truncated body
**Command**: `importPdf("/path/to/corrupted.pdf")`
**Assertions**:
- Return is `{ ok: false, error: { code: "PDF_CORRUPTED" } }`
- No ScoreEntry created
- No files written to disk

### T-B-PDF-005: Password-protected PDF
**Setup**: Create password-protected PDF
**Command**: `importPdf("/path/to/protected.pdf")`
**Assertions**:
- Return is `{ ok: false, error: { code: "PDF_PASSWORD_PROTECTED" } }`
- No ScoreEntry created

### T-B-PDF-006: Empty PDF (0 pages)
**Setup**: Create valid PDF with no pages
**Command**: `importPdf("/path/to/empty.pdf")`
**Assertions**:
- Return is `{ ok: false, error: { code: "PDF_EMPTY" } }`
- No ScoreEntry created

### T-B-PDF-007: File does not exist
**Setup**: None
**Command**: `importPdf("/nonexistent/file.pdf")`
**Assertions**:
- Return includes ImportError (code: file not found)
- No exception thrown (graceful failure)

---

## Unit Tests: importImage()

### T-B-IMG-001: Valid JPEG image
**Setup**: Create 2400×1800 JPEG, 5 MB
**Command**: `importImage(jpegBytes)`
**Assertions**:
- Return is `{ ok: true, value: ScoreEntry }`
- ScoreEntry.sourceType == "image"
- File written as PNG
- SHA256 hash stored in metadata

### T-B-IMG-002: Valid PNG image
**Setup**: Create 2400×1800 PNG, 8-bit RGB
**Command**: `importImage(pngBytes)`
**Assertions**:
- Return is `{ ok: true, value: ScoreEntry }`
- File written, hash stored

### T-B-IMG-003: PNG with alpha channel
**Setup**: Create 2400×1800 PNG with RGBA
**Command**: `importImage(pngRgbaBytes)`
**Assertions**:
- Accepted (alpha channel allowed)
- ScoreEntry created

### T-B-IMG-004: Progressive JPEG
**Setup**: Create progressive JPEG
**Command**: `importImage(jpegProgressiveBytes)`
**Assertions**:
- Accepted and imported
- ScoreEntry created

### T-B-IMG-005: Image exactly at minimum (200×200)
**Setup**: Create 200×200 PNG
**Command**: `importImage(bytes)`
**Assertions**:
- Accepted (boundary inclusive)
- ScoreEntry created

### T-B-IMG-006: Image below minimum (199×199)
**Setup**: Create 199×199 PNG
**Command**: `importImage(bytes)`
**Assertions**:
- Return is `{ ok: false, error: { code: "IMAGE_DIMENSIONS_TOO_SMALL" } }`
- Error details include actual dimensions

### T-B-IMG-007: Image exactly at maximum (4800×3600)
**Setup**: Create 4800×3600 PNG
**Command**: `importImage(bytes)`
**Assertions**:
- Accepted (boundary inclusive)
- ScoreEntry created

### T-B-IMG-008: Image exceeds maximum (4801×3601)
**Setup**: Create 4801×3601 PNG
**Command**: `importImage(bytes)`
**Assertions**:
- Return is `{ ok: false, error: { code: "IMAGE_DIMENSIONS_TOO_LARGE" } }`

### T-B-IMG-009: Image file exactly 50 MB
**Setup**: Create PNG with exactly 52,428,800 bytes
**Command**: `importImage(bytes)`
**Assertions**:
- Accepted (boundary inclusive)
- ScoreEntry created

### T-B-IMG-010: Image file exceeds 50 MB
**Setup**: Create 60 MB file (or simulate with sparse file)
**Command**: `importImage(bytes)`
**Assertions**:
- Return is `{ ok: false, error: { code: "IMAGE_FILE_TOO_LARGE" } }`
- Error details include actual size and limit

### T-B-IMG-011: Invalid image format (GIF)
**Setup**: Create GIF file
**Command**: `importImage(gifBytes)`
**Assertions**:
- Return is `{ ok: false, error: { code: "IMAGE_INVALID_FORMAT" } }`

### T-B-IMG-012: Corrupted JPEG
**Setup**: Create file with JPEG magic bytes but truncated body
**Command**: `importImage(corruptedBytes)`
**Assertions**:
- Return is `{ ok: false, error: { code: "IMAGE_INVALID_FORMAT" } }` or similar
- No ScoreEntry created

---

## Unit Tests: importMusicXml()

### T-B-XML-001: Valid MusicXML 3.0
**Setup**: Create well-formed MusicXML 3.0 (e.g., "Twinkle Twinkle" 4 measures, treble clef)
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Return is `{ ok: true, value: ScoreEntry }`
- ScoreEntry.sourceType == "musicxml"
- versions["omr_musicxml"] present (stores XML string)
- versions["omr_score_json"] present (stores converted Score JSON)
- Both versions have non-empty content

### T-B-XML-002: Valid MusicXML 3.1
**Setup**: Create MusicXML 3.1 compliant file
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Accepted (version 3.1 supported)
- ScoreEntry created

### T-B-XML-003: MusicXML with work-title and composer
**Setup**: MusicXML with `<work-title>` and `<composer>` elements
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- ScoreEntry.title extracted from work-title
- ScoreEntry.composer extracted from composer element

### T-B-XML-004: MusicXML without optional metadata
**Setup**: MusicXML without work-title, composer
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Accepted (optional fields)
- ScoreEntry.title defaults to "Untitled" or first measure number
- ScoreEntry.composer defaults to empty string

### T-B-XML-005: MusicXML with multiple parts
**Setup**: Grand staff (piano) with treble and bass clefs
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Accepted
- Score JSON reflects both parts

### T-B-XML-006: MusicXML minimum content (1 part, 1 measure)
**Setup**: Single part with single measure
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Accepted
- ScoreEntry created

### T-B-XML-007: Unclosed XML tag
**Setup**: MusicXML with missing closing `</measure>` tag
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Return is `{ ok: false, error: { code: "XML_MALFORMED" } }`
- Error details include line number

### T-B-XML-008: Invalid XML entity
**Setup**: MusicXML with undefined entity reference
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Return is `{ ok: false, error: { code: "XML_MALFORMED" } }`

### T-B-XML-009: Schema validation failure (unknown element)
**Setup**: Valid XML with non-standard MusicXML element (e.g., `<my-custom-element>`)
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Return is `{ ok: false, error: { code: "XML_SCHEMA_INVALID" } }`

### T-B-XML-010: Unsupported version 2.0
**Setup**: MusicXML with `<score-partwise version="2.0">`
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Return is `{ ok: false, error: { code: "XML_UNSUPPORTED_VERSION" } }`
- Error details include actual version

### T-B-XML-011: Empty content (0 parts)
**Setup**: MusicXML with score-partwise but no part-list
**Command**: `importMusicXml(xmlString)`
**Assertions**:
- Return is `{ ok: false, error: { code: "PARSE_CONTENT_EMPTY" } }`

### T-B-XML-012: Compressed .musicxml.zip
**Setup**: Create MusicXML as compressed ZIP
**Command**: `importMusicXml(xmlString)` (if bytes/zip support is included)
**Assertions**:
- Decompressed and parsed
- ScoreEntry created (if supported)

---

## Unit Tests: Version Management

### T-B-VER-001: List versions after import
**Setup**: Import image
**Command**: `getScore(id)` → iterate versions
**Assertions**:
- Exactly one version present (original_image)
- Version.isActive == true
- Version.createdAt is ISO 8601 UTC
- Version.metadata contains checksumSHA256

### T-B-VER-002: Multiple versions for same score (simulated)
**Setup**: Import image, then manually add edited version to DB
**Command**: `getScore(id)` → iterate versions
**Assertions**:
- Two versions present
- Only one has isActive == true
- Both retained in versions map

### T-B-VER-003: Version content retrieval
**Setup**: Import image
**Command**: `getScore(id).versions["original_image"].content`
**Assertions**:
- Returns file path
- File exists and is readable
- File is valid PNG

---

## Unit Tests: Library CRUD

### T-B-LIB-001: Empty library
**Setup**: Fresh SQLite database
**Command**: `getLibrary()`
**Assertions**:
- Returns empty list `[]`

### T-B-LIB-002: Add single score
**Setup**: Fresh database
**Command**: `importImage(bytes)` → `getLibrary()`
**Assertions**:
- List contains 1 ScoreEntry
- Entry matches returned from import

### T-B-LIB-003: Add multiple scores
**Setup**: Fresh database
**Command**: Import 5 different images → `getLibrary()`
**Assertions**:
- List contains 5 ScoreEntry objects
- Sorted by createdAt descending (newest first)

### T-B-LIB-004: Get single score
**Setup**: Import 3 scores
**Command**: `getScore(id)` where id = middle score
**Assertions**:
- Returns correct ScoreEntry
- All fields match (id, title, composer, versions)

### T-B-LIB-005: Get non-existent score
**Setup**: Import 1 score
**Command**: `getScore(randomUuid)`
**Assertions**:
- Returns null
- No exception

### T-B-LIB-006: Delete score
**Setup**: Import 3 scores, note one id
**Command**: `deleteScore(id)` → `getLibrary()`
**Assertions**:
- Returns true
- Deleted score not in library
- Other 2 scores remain
- Files in `versions/{id}/` deleted

### T-B-LIB-007: Delete non-existent score
**Setup**: Import 1 score
**Command**: `deleteScore(randomUuid)`
**Assertions**:
- Returns false
- Library unchanged

### T-B-LIB-008: Library sorting
**Setup**: Import 3 scores at T1, T2, T3 (T1 < T2 < T3)
**Command**: `getLibrary()`
**Assertions**:
- First item createdAt = T3
- Last item createdAt = T1
- Verified reverse chronological order

---

## Integration Tests: Storage Persistence

### T-B-PERSIST-001: Restart app, library intact
**Setup**: Import 2 scores (image, MusicXML)
**Command**: Close database → reopen same database → `getLibrary()`
**Assertions**:
- Both scores present
- All metadata recovered
- Version files readable
- No data loss

### T-B-PERSIST-002: File integrity after restart
**Setup**: Import image, record file path
**Command**: Close app → reopen → verify file exists and is readable
**Assertions**:
- PNG file still valid
- Checksum matches metadata

---

## Integration Tests: Concurrent Operations

### T-B-CONC-001: Concurrent reads
**Setup**: Import 1 score
**Command**: Spawn 10 threads, each calls `getLibrary()` and `getScore(id)` 100x
**Assertions**:
- All threads complete without error
- All return identical data
- No data corruption

### T-B-CONC-002: Concurrent write to different scores
**Setup**: Fresh database
**Command**: Spawn 5 threads, each imports different image
**Assertions**:
- All imports succeed
- 5 scores in final library
- All metadata correct
- No duplicate ids

### T-B-CONC-003: Concurrent delete
**Setup**: Import 10 scores
**Command**: Spawn 5 threads, each deletes 2 different scores
**Assertions**:
- All deletes succeed (or some fail gracefully)
- Final library has 0 or 10 scores (not partial)
- No orphaned files

---

## Error Handling Tests

### T-B-ERR-001: Storage write failure
**Setup**: Make `versions/` directory read-only
**Command**: `importImage(bytes)`
**Assertions**:
- Return is `{ ok: false, error: { code: "STORAGE_WRITE_FAILED" } }`
- No database entry created
- No orphaned files

### T-B-ERR-002: Database corruption recovery
**Setup**: SQLite database corrupted mid-transaction
**Command**: Retry operation
**Assertions**:
- Database recovered (or clean error)
- Operation retried successfully

---

## Performance Tests (Threshold-based)

### T-B-PERF-001: PDF import time (1-page)
**Threshold**: ≤500 ms
**Setup**: Single-page PDF
**Command**: `importPdf(path)` timed
**Metric**: Elapsed milliseconds
**Pass**: Result < threshold

### T-B-PERF-002: PDF import time (100-page)
**Threshold**: ≤5000 ms
**Setup**: 100-page PDF
**Command**: Timed import
**Metric**: ms

### T-B-PERF-003: Image import time
**Threshold**: ≤200 ms
**Setup**: 2400×1800 image
**Command**: Timed import
**Metric**: ms

### T-B-PERF-004: MusicXML parse time
**Threshold**: ≤300 ms
**Setup**: 100-measure MusicXML
**Command**: Timed parse
**Metric**: ms

### T-B-PERF-005: Library query time (1000 scores)
**Threshold**: ≤100 ms
**Setup**: Database with 1000 ScoreEntry records
**Command**: Timed `getLibrary()`
**Metric**: ms

---

## Test Execution Checklist
- [ ] All unit tests for importPdf (7 tests)
- [ ] All unit tests for importImage (12 tests)
- [ ] All unit tests for importMusicXml (12 tests)
- [ ] All version management tests (3 tests)
- [ ] All library CRUD tests (8 tests)
- [ ] All storage persistence tests (2 tests)
- [ ] All concurrent operation tests (3 tests)
- [ ] All error handling tests (2 tests)
- [ ] All performance tests (5 tests)
- [ ] Total: 54 test cases

**Pass Criteria**: 54/54 pass, 0 failures, 0 timeouts
