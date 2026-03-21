/// Error codes for import operations.
enum ImportError {
  // PDF errors
  pdfCorrupted('PDF_CORRUPTED', 'PDF file is corrupted or not readable'),
  pdfPasswordProtected('PDF_PASSWORD_PROTECTED', 'PDF requires a password'),
  pdfEmpty('PDF_EMPTY', 'PDF has no pages'),
  pdfExtractionFailed('PDF_EXTRACTION_FAILED', 'Failed to extract pages from PDF'),

  // Image errors
  imageInvalidFormat('IMAGE_INVALID_FORMAT', 'Not a valid JPEG or PNG image'),
  imageDimensionsTooSmall('IMAGE_DIMENSIONS_TOO_SMALL', 'Image dimensions < 200×200 px'),
  imageDimensionsTooLarge('IMAGE_DIMENSIONS_TOO_LARGE', 'Image dimensions > 4800×3600 px'),
  imageFileTooLarge('IMAGE_FILE_TOO_LARGE', 'Image file > 50 MB'),

  // MusicXML errors
  xmlMalformed('XML_MALFORMED', 'XML is not well-formed'),
  xmlSchemaInvalid('XML_SCHEMA_INVALID', 'XML does not conform to MusicXML 3.0/3.1'),
  xmlUnsupportedVersion('XML_UNSUPPORTED_VERSION', 'MusicXML version is not 3.0 or 3.1'),
  xmlContentEmpty('XML_CONTENT_EMPTY', 'MusicXML has no parts or measures'),

  // Storage errors
  storageWriteFailed('STORAGE_WRITE_FAILED', 'Failed to write to disk'),
  storageDuplicateDetected('STORAGE_DUPLICATE_DETECTED', 'Score with this content already exists'),

  // File validation errors
  fileNotFound('FILE_NOT_FOUND', 'File does not exist'),
  fileAccessDenied('FILE_ACCESS_DENIED', 'Cannot read file'),
  fileInvalidExtension('FILE_INVALID_EXTENSION', 'Invalid file extension');

  final String code;
  final String message;

  const ImportError(this.code, this.message);

  @override
  String toString() => '$code: $message';
}
