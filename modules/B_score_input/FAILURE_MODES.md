# Module B: Score Input & Library - Failure Modes

## F-B01: Invalid PDF

**Condition**:
- PDF file is corrupted (unreadable header, truncated file, checksum fails)
- File magic bytes do not match PDF signature (`%PDF-`)
- PDF version > 2.0 (future-incompatible)

**Detection Method**:
1. Read first 5 bytes, verify `%PDF-` sequence
2. Parse cross-reference table (xref)
3. Attempt to decompress first page stream
4. If any step fails, mark as corrupted

**Recovery Action**:
- Return ImportError with code `PDF_CORRUPTED`
- Do not create ScoreEntry
- Log corrupted file path for debugging
- User must provide different file

**Test Case**:
```
Input: PDF file with corrupted xref table
Command: importPdf("/path/to/corrupted.pdf")
Expected: Result { ok: false, error: { code: "PDF_CORRUPTED" } }
Verify: No ScoreEntry created in DB
```

---

## F-B02: Image Too Small

**Condition**:
- Image width < 200 pixels OR height < 200 pixels
- Applies to both imported JPEG/PNG and PDF-extracted images
- Measured after decompression, in actual pixel dimensions

**Detection Method**:
1. Decode image header (JFIF or PNG IHDR chunk)
2. Extract width and height fields
3. Compare: if (width < 200) OR (height < 200), fail

**Recovery Action**:
- Return ImportError with code `IMAGE_DIMENSIONS_TOO_SMALL`
- Include actual dimensions in error details: `{ actualWidth: int, actualHeight: int }`
- Do not create ScoreEntry
- User may re-scan with camera at higher resolution

**Test Case**:
```
Input: PNG image 150×150 pixels
Command: importImage(bytes)
Expected: Result { ok: false, error: { code: "IMAGE_DIMENSIONS_TOO_SMALL", details: { actualWidth: 150, actualHeight: 150 } } }
Verify: No ScoreEntry created
```

---

## F-B03: Image Too Large

**Condition**:
- Image file size > 50 MB (measured as byte count)
- OR image decoded pixel data > 4800×3600 resolution
- Applies before decompression completes

**Detection Method**:
1. Check file size on disk (file.stat().size)
2. If ≤50 MB, decode image header
3. Check decoded dimensions: if (width > 4800) OR (height > 3600), fail
4. If size check fails, abort before decompression

**Recovery Action**:
- Return ImportError with code `IMAGE_FILE_TOO_LARGE` (for file size) or `IMAGE_DIMENSIONS_TOO_LARGE` (for pixel dimensions)
- Include size in error details: `{ actualSizeBytes: long, maxAllowed: long }`
- Do not create ScoreEntry
- User must reduce image resolution or split multi-page scan

**Test Case - File Size**:
```
Input: 60 MB PNG file
Command: importImage(bytes)
Expected: Result { ok: false, error: { code: "IMAGE_FILE_TOO_LARGE", details: { actualSizeBytes: 62914560, maxAllowedBytes: 52428800 } } }
Verify: No storage write occurs
```

**Test Case - Dimensions**:
```
Input: PNG 5000×5000 pixels
Command: importImage(bytes)
Expected: Result { ok: false, error: { code: "IMAGE_DIMENSIONS_TOO_LARGE", details: { actualWidth: 5000, actualHeight: 5000 } } }
```

---

## F-B04: MusicXML Parse Error

**Condition**:
- XML is malformed (unclosed tags, invalid entities, encoding issues)
- XML conforms to XML 1.0 spec but not MusicXML 3.0/3.1 schema
- MusicXML version attribute is not "3.0" or "3.1"
- Content is empty (0 parts, 0 measures, or work-title missing in header)

**Detection Method**:
1. Attempt XML parse with strict validation
2. If parse fails, return error with line number
3. If parse succeeds, validate against XSD schema
4. Check version attribute: `<score-partwise version="X.Y">`
5. Check for at least 1 part and 1 measure

**Recovery Action**:
- Return ParseError with code `XML_MALFORMED`, `XML_SCHEMA_INVALID`, `XML_UNSUPPORTED_VERSION`, or `PARSE_CONTENT_EMPTY`
- Include line number and context in error details
- Do not create ScoreEntry
- User must correct XML or export from compatible notation software

**Test Case - Malformed**:
```
Input: MusicXML with unclosed <measure> tag
Command: importMusicXml(xmlString)
Expected: Result { ok: false, error: { code: "XML_MALFORMED", details: { line: 42, message: "Unexpected end of file" } } }
```

**Test Case - Schema Invalid**:
```
Input: Valid XML but with invalid MusicXML element (e.g., <invalid-element>)
Command: importMusicXml(xmlString)
Expected: Result { ok: false, error: { code: "XML_SCHEMA_INVALID", details: { violations: [...] } } }
```

**Test Case - Unsupported Version**:
```
Input: MusicXML with version="2.0"
Command: importMusicXml(xmlString)
Expected: Result { ok: false, error: { code: "XML_UNSUPPORTED_VERSION", details: { version: "2.0" } } }
```

**Test Case - Empty Content**:
```
Input: MusicXML with 1 part but 0 measures
Command: importMusicXml(xmlString)
Expected: Result { ok: false, error: { code: "PARSE_CONTENT_EMPTY" } }
```

---

## F-B05: Storage Write Failure

**Condition**:
- Disk is full (no space remaining for write)
- Permission denied on target directory (read-only filesystem or insufficient user privileges)
- File handle exhausted (OS limit on open files)
- Database is locked (another process holds write lock)
- Filesystem is disconnected (network drive, USB unplugged)

**Detection Method**:
1. Attempt to write file/DB record
2. Catch OS-level exceptions: IOException, EIO, EACCES, ENOSPC, EAGAIN
3. Log exception type and message
4. Do not retry automatically

**Recovery Action**:
- Return ImportError with code `STORAGE_WRITE_FAILED`
- Include OS error code in details: `{ osError: string, path: string }`
- Rollback any partial writes (delete partial file, rollback DB transaction)
- User must resolve storage issue (free space, permissions, remount) and retry

**Test Case - No Space**:
```
Setup: Fill filesystem to 0 bytes free
Command: importImage(largeImageBytes)
Expected: Result { ok: false, error: { code: "STORAGE_WRITE_FAILED", details: { osError: "ENOSPC" } } }
Verify: No ScoreEntry in DB, no partial files on disk
```

**Test Case - Permission Denied**:
```
Setup: Make versions/ directory read-only (chmod 444)
Command: importImage(bytes)
Expected: Result { ok: false, error: { code: "STORAGE_WRITE_FAILED", details: { osError: "EACCES" } } }
Cleanup: Restore permissions
```

---

## F-B06: Score Not Found

**Condition**:
- `getScore(id)` called with non-existent UUID
- `deleteScore(id)` called with non-existent UUID
- `exportMusicXml(id)` called with non-existent UUID
- UUID format is invalid (not 36-char hex with dashes)

**Detection Method**:
1. Parse id as UUID: validate format `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
2. Query SQLite: `SELECT * FROM scores WHERE id = ?`
3. If no result, score not found

**Recovery Action**:
- `getScore`: Return null (no error)
- `deleteScore`: Return false (no error)
- `exportMusicXml`: Return null (no error)
- Invalid UUID format: Treat as not found (return null/false)

**Test Case - Get Non-Existent**:
```
Setup: No scores in library
Command: getScore("00000000-0000-0000-0000-000000000000")
Expected: null
Verify: No exception, DB query executes
```

**Test Case - Delete Non-Existent**:
```
Setup: No scores in library
Command: deleteScore("00000000-0000-0000-0000-000000000000")
Expected: false
Verify: No exception, no files deleted
```

**Test Case - Invalid UUID Format**:
```
Command: getScore("invalid-id")
Expected: null
```

---

## F-B07: Duplicate Import Detection

**Condition**:
- Same PDF file imported twice (detected by file hash)
- Same image bytes imported twice (detected by SHA256)
- Same MusicXML content imported twice (detected by normalized XML hash)
- No deduplication at import time; library contains duplicates

**Detection Method**:
1. Compute hash of input: SHA256(fileBytes) for images, SHA256(xmlContent) for MusicXML
2. Query SQLite for existing score with matching hash
3. Record hash in Version metadata

**Recovery Action**:
- Do NOT prevent duplicate import at this layer
- Module B creates new ScoreEntry with unique id
- Module C (comparison) or user UI may flag duplicates
- Log warning: "Duplicate score imported: {fileName} matches {existingId}"

**Test Case - Image Duplicate**:
```
Setup: Import image1.jpg (score ID = A)
Command: importImage(same image bytes)
Expected: New ScoreEntry created with ID = B (≠ A)
Verify: Both scores in library, hash matches in metadata
```

**Test Case - MusicXML Duplicate**:
```
Setup: importMusicXml(file.xml) → ScoreEntry ID = X
Command: importMusicXml(identical file.xml)
Expected: New ScoreEntry created with ID = Y (≠ X)
Verify: Both in library, hash comparison possible via metadata
```

---

## Summary Table

| Code | Condition | Detection | User Action | Test Method |
|------|-----------|-----------|-------------|-------------|
| F-B01 | PDF corrupted | Magic bytes, xref parse | Provide valid PDF | Read corrupted PDF |
| F-B02 | Image < 200×200 | Decode header | Re-scan higher res | Import 150×150 PNG |
| F-B03 | Image > 50MB or > 4800×3600 | File size, dimensions | Compress or split | Import 60MB file |
| F-B04 | MusicXML malformed/invalid | XML/XSD validation | Fix XML | Import invalid XML |
| F-B05 | Storage write fails | OS exception catch | Free space or check perms | Fill disk, retry |
| F-B06 | Score not found | DB query returns null | N/A (return null) | Query non-existent id |
| F-B07 | Duplicate import | Hash comparison | N/A (allow duplicate) | Import same file twice |
