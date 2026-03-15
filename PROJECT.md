# Paper Tide - Project Documentation

## Project Overview

**Project Name:** Paper Tide  
**Type:** Per-Tenant Extension (PTE)  
**Version:** 1.0.2.0
**Target Platform:** Microsoft Dynamics 365 Business Central  
**Minimum Version:** 2024 Release Wave 2 (v27.4)  
**Runtime Version:** 14.0  

## Purpose

Automate the creation of purchase invoices in Business Central by extracting data from invoice images using AI vision models (any OpenAI-compatible API). The solution provides a preview workflow where users can review and edit AI-extracted data before committing to the database.

## Business Value

- **Time Savings:** Reduce manual data entry time by 80%+
- **Accuracy:** Minimize typos and data entry errors
- **Audit Trail:** Original image attached to preview for verification
- **Flexibility:** Configurable to work with various invoice formats
- **Integration:** Native Business Central experience

## Scope

### In Scope (v1.0)

- **Batch Import** - Upload multiple invoice images with queue management
- **Concurrency Control** - Process up to 3 images simultaneously (configurable)
- **Import Queue** - Review and manage all imported documents in a list
- AI extraction via OpenAI-compatible vision API
- Preview page with original image display
- Manual review and editing capability
- Creation of standard Purchase Invoices
- Configuration page for API settings
- System prompt customization
- Default G/L Account for invoice lines
- **AI GL Account Suggestion** - AI analyzes chart of accounts and suggests appropriate G/L accounts per line
- **Vendor Name Learning** - Learned vendor name aliases for automatic matching on subsequent imports
- **Multi-Field Vendor Matching** - Match vendors by name mapping, vendor no., VAT no., bank account/IBAN, exact name, or partial name
- **Fraud Detection** - Cross-validate extracted VAT/bank data against known vendor records
- **Auto Coding** - Separate text AI model for G/L account prediction with confidence scoring

### Out of Scope (v1.0)

- Multi-page PDF support (first page only currently)
- Multi-language OCR optimization
- Mobile device camera integration
- VAT calculation validation

## Architecture Decisions

### Why OpenAI-Compatible API?

- Provider-agnostic: works with OpenAI, DashScope, Azure OpenAI, Groq, Ollama, etc.
- Strong vision capabilities for document understanding
- JSON-structured output support
- Built-in provider presets for quick setup

### PDF Conversion via Gotenberg

- Business Central AL has no built-in PDF rendering capability
- PDF files are converted to PNG images at upload time via external Gotenberg service
- Gotenberg uses Chromium + pdf.js to render PDF pages as high-quality images
- Only first page is converted (sufficient for most invoices)

### Why Temporary Table for Preview?

- No database persistence until user confirms
- Easy to discard and restart
- Supports complex field editing
- Can display in standard page framework

## Object Catalog

### Tables

| ID | Name | Type | Records |
|----|------|------|---------|
| 50100 | PaperTide AI Setup | Singleton | 1 |
| 50101 | PaperTide Temp Invoice Buffer | Temporary | Session-only |
| 50102 | PaperTide Import Doc. Header | Persistent | One per uploaded image |
| 50103 | PaperTide Import Doc. Line | Persistent | Invoice lines per document |
| 50104 | PaperTide Vendor Name Mapping | Persistent | Learned vendor name aliases |

**AI Extraction Setup Fields:**
- API Base URL, API Key, Model Name
- Max Tokens, Temperature, Request Timeout
- Default G/L Account
- **Enable AI GL Suggestion** - Activates AI-powered G/L account suggestions
- **Chart of Accounts Context** - Cached G/L accounts for AI context
- **Enable PDF Conversion** - Activates PDF upload with automatic image conversion
- **PDF Converter Endpoint** - Gotenberg service URL

### Pages

| ID | Name | Type | Source Table |
|----|------|------|--------------|
| 50100 | PaperTide AI Setup | Card | PaperTide AI Setup |
| 50101 | PaperTide Invoice Preview | Card | PaperTide Import Doc. Header |
| 50102 | PaperTide Inv. Preview Subform | ListPart | PaperTide Import Doc. Line |
| 50103 | PaperTide Inv. Image FactBox | CardPart | PaperTide Import Doc. Header |
| 50104 | PaperTide Batch Upload | Card | - |
| 50105 | PaperTide Import Documents | List | PaperTide Import Doc. Header |
| 50106 | PaperTide Vendor Mappings | List | PaperTide Vendor Name Mapping |

### Codeunits

| ID | Name | Access | Purpose |
|----|------|--------|---------|
| 50100 | PaperTide AI Vision API | Internal | HTTP communication with AI service |
| 50101 | PaperTide Invoice Extraction | Internal | JSON parsing and invoice creation |
| 50102 | PaperTide Batch Processing Mgt | Internal | Queue management and concurrency control |
| 50103 | PaperTide Batch API Worker | Internal | Individual document processing |
| 50104 | PaperTide PDF Converter | Internal | PDF-to-image conversion via Gotenberg |
| 50106 | PaperTide GL Account Predictor | Internal | G/L account prediction via text AI model |

### Enums

| ID | Name | Values |
|----|------|--------|
| 50100 | PaperTide Import Doc. Status | Pending, Ready, Created, Discarded |
| 50101 | PaperTide Import Proc. Status | Pending, Processing, Completed, Error |
| 50102 | PaperTide Inv. Verif. Status | Not Checked, Verified, Warning, Suspicious |

### Page Extensions

| ID | Name | Extends |
|----|------|---------|
| 50100 | PaperTide Purch. Inv. List Ext | Purchase Invoices |

### Permission Sets

| ID | Name | Permissions |
|----|------|-------------|
| 50100 | PaperTide | Full access to all objects |

## AI GL Account Suggestion Feature

### Overview
The AI GL Account Suggestion feature leverages the AI model's understanding of both the invoice content and your chart of accounts to automatically suggest the most appropriate G/L account for each invoice line.

### How It Works

1. **Setup Phase**
   - User enables "Enable AI GL Suggestion" in AI Extraction Setup
   - User clicks "Refresh Chart of Accounts" to cache the G/L account list
   - System stores up to 100 posting accounts in the cache

2. **Processing Phase**
   - When processing an invoice, the cached chart of accounts is included in the system prompt
   - AI analyzes each line description against available G/L accounts
   - AI returns `GLAccountNo` in the JSON response for each line

3. **Fallback Logic**
   - If AI suggests a valid account → Use AI suggestion
   - If AI returns empty or invalid → Use Default G/L Account from setup
   - User can always override in the Preview page

### Technical Implementation

- **Cache Storage:** `Chart of Accounts Context` blob field in AI Extraction Setup
- **Cache Refresh:** Manual via "Refresh Chart of Accounts" action
- **Prompt Enhancement:** `GetSystemPromptWithChartOfAccounts()` appends account list to system prompt
- **JSON Parsing:** `ParseAndSaveToImportDoc` extracts `GLAccountNo` from AI response

### Performance Considerations

- Chart of accounts is cached to avoid database reads on every API call
- Cache is read from blob storage (fast) rather than G/L Account table
- Maximum 100 accounts included to manage token usage

## Workflow

### 1. Upload Workflow (Batch Upload)

```
User clicks "Batch Upload Invoices" action
    ↓
"Select Files" button opens file dialog
    ↓
User selects one or more files (JPG/JPEG/PNG/PDF)
    ↓
For each file:
    - Validate file extension
    - If PDF: convert to PNG via Gotenberg
    - Save image to Image Blob field
    - Create Import Document Header record
    - Set status to "Pending"
    ↓
Auto-start processing if concurrency available
```

### 2. Processing Workflow (Background)

```
Batch Processing Mgt checks for pending documents
    ↓
If concurrency slot available (< 3 processing):
    - Start Batch API Worker
    - Set status to "Processing"
    ↓
Batch API Worker:
    - Read image from Image Blob
    - Convert to Base64
    - Call AI Vision API
    - Parse JSON response
    - Save extracted data to Import Document Header/Line
    - Set status to "Ready" (success) or "Error" (failure)
    ↓
Process next pending document if available
```

### 3. Review & Approval Workflow

```
User opens "Import Document Queue"
    ↓
Select document with status "Ready"
    ↓
"Review & Edit" opens Invoice Preview page
    ↓
User can:
    - View extracted data
    - Edit fields (toggle edit mode)
    - View original image in FactBox
    - Click "Accept & Create Invoice"
    ↓
System validates:
    - Vendor No. is specified
    - Invoice No. is specified
    - No duplicate vendor invoice no.
    ↓
Create Purchase Invoice:
    - Create Purchase Header
    - Create Purchase Lines (with Default G/L Account from setup)
    - Update Import Document status to "Created"
    - Set "Created Invoice No."
    ↓
Open created Purchase Invoice
```

### 4. Error Handling Workflow

```
If processing fails:
    - Set Processing Status to "Error"
    - Save error message to "Error Message" field
    - User can view error in Import Document Queue
    - User can "Retry" processing
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                            │
│  Purchase Invoices Page → Batch Upload Invoices action           │
│                         → View Import Queue action               │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FILE HANDLING                               │
│  - File upload dialog (UploadIntoStream)                         │
│  - Extension validation (JPG, JPEG, PNG, PDF)                    │
│  - MIME type detection                                           │
│  - Save to Image Blob field                                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BATCH PROCESSING                            │
│  PaperTide Batch Processing Mgt Codeunit                         │
│  - Queue management with concurrency control (max 3)             │
│  - Status tracking: Pending → Processing → Ready/Error           │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AI SERVICE CALL                             │
│  PaperTide AI Vision API Codeunit                                │
│  - Read Image Blob → Convert to Base64                           │
│  - HTTP POST to {API Base URL}/chat/completions                  │
│  - Request body: model, messages (system prompt + image)         │
│  - Headers: Authorization: Bearer {API Key}                      │
│  - Timeout handling (configurable, default 60s)                  │
│  - Error handling with detailed messages                         │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      RESPONSE PROCESSING                         │
│  - Parse JSON response                                           │
│  - Navigate: choices[0].message.content                          │
│  - Clean markdown formatting (```json ... ```)                   │
│  - Validate JSON structure                                       │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATA EXTRACTION                             │
│  PaperTide Invoice Extraction Codeunit                           │
│  - Map JSON fields to Import Document fields                     │
│  - Vendor lookup (6-step priority):                              │
│    1. Vendor Name Mapping (learned aliases)                      │
│    2. By Vendor No. (exact match)                                │
│    3. By VAT Registration No.                                    │
│    4. By Bank Account/IBAN                                       │
│    5. By Vendor Name (exact match)                               │
│    6. By Vendor Name (partial match with @*...*)                 │
│  - Parse dates (ISO 8601 format: YYYY-MM-DD)                     │
│  - Process line items array to Import Document Line              │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PREVIEW & REVIEW                            │
│  Invoice Preview Page (Card Page)                                │
│  - Source Table: Import Document Header                          │
│  - Editable: Toggle with "Edit Values" action                    │
│  - Subform: Invoice Preview Subform V2 (Import Document Line)    │
│  - FactBox: Invoice Image FactBox V2 (Image Blob display)        │
│  - Locked when "Created Invoice No." is set                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      INVOICE CREATION                            │
│  PaperTide Invoice Extraction.CreateInvoiceFromImportDoc         │
│  - Validate: Vendor No., Invoice No. required                    │
│  - Check for duplicate Vendor Invoice No.                        │
│  - Create Purchase Header (Document Type = Invoice)              │
│  - Create Purchase Lines:                                        │
│    - Type = G/L Account                                          │
│    - No. = Default G/L Account from setup (if configured)        │
│    - Description, Quantity, Unit Price, Amount from lines        │
│  - If no lines: Create one line with total amount                │
│  - Update Import Document: Status = Created, Created Invoice No. │
│  - Open created Purchase Invoice                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Security Considerations

| Aspect | Implementation |
|--------|---------------|
| API Key Storage | SecretText data type (encrypted at rest) |
| HTTP Security | HTTPS only (enforced by URL validation) |
| File Upload | Whitelist validation (JPG/JPEG/PNG/PDF) |
| Data Classification | CustomerContent for all setup data |
| Permissions | Dedicated permission set |

## Configuration Reference

### AI Extraction Setup Fields

| Field | Data Type | Default | Valid Range |
|-------|-----------|---------|-------------|
| API Base URL | Text[250] | - | Valid HTTPS URL |
| API Key | SecretText | - | Non-empty |
| Model Name | Text[50] | - | Any valid vision model |
| Max Tokens | Integer | 2048 | 100-4096 |
| Temperature | Decimal | 0.1 | 0.0-2.0 |
| Request Timeout | Integer | 60000 | 10000-300000 |
| System Prompt | Blob | Default prompt | Any valid text |

## Testing Checklist

### Unit Testing

- [ ] API connection test returns success with valid credentials
- [ ] API connection test fails with invalid credentials
- [ ] Image to Base64 conversion works correctly
- [ ] JSON response parsing handles valid responses
- [ ] JSON response parsing handles malformed responses
- [ ] Date parsing works for ISO 8601 format
- [ ] Vendor lookup by number works
- [ ] Vendor lookup by name works
- [ ] Vendor lookup by partial name works

### Integration Testing

- [ ] Full flow: Upload → Extract → Preview → Create
- [ ] Invoice creation with all fields populated
- [ ] Invoice creation with minimal fields
- [ ] Edit mode allows field modification
- [ ] Duplicate invoice detection works
- [ ] Error handling for network failures
- [ ] Error handling for API errors
- [ ] Error handling for invalid images

### User Acceptance Testing

- [ ] Clear and helpful error messages
- [ ] Preview page is intuitive
- [ ] Image display is clear
- [ ] Edit mode is discoverable
- [ ] Workflow feels natural to AP clerks

## Known Limitations

1. **PDF First Page Only** - Multi-page PDFs are converted using only the first page
2. **No Auto-Post** - Invoices created as open, not posted
3. **GL Account Assignment** - Lines use Default G/L Account from setup; user may need to adjust
4. **Single Currency** - Currency must be specified; no automatic detection
5. **Manual Upload Only** - No automated import from cloud storage (Azure File Storage planned for v2.0)

## Business Logic

### Status Flow

```
Pending → Processing → Ready → Created
   ↓          ↓         ↓
   └──────────┴─────────┘→ Error
```

| Status | Description | Actions Available |
|--------|-------------|-------------------|
| Pending | Document uploaded, waiting for processing | View, Delete |
| Processing | AI extraction in progress | View only |
| Ready | Extraction complete, ready for review | Review & Edit, Create Invoice |
| Created | Invoice already created from document | View Created Invoice only |
| Error | Processing failed with error | View Error, Retry |
| Discarded | Manually discarded by user | None |

### Concurrency Control

- Maximum 3 documents processed simultaneously
- Additional documents queued automatically
- Queue processed FIFO (First In, First Out)

### Vendor Matching Logic

1. **Vendor Name Mapping** - Learned aliases from previous user corrections (exact match)
2. **Exact Vendor No.** - If extracted VendorNo matches a Vendor record
3. **VAT Registration No.** - Match extracted VAT No. against Vendor."VAT Registration No."
4. **Bank Account/IBAN** - Match extracted bank account against registered Vendor Bank Account records
5. **Exact Name Match** - If Vendor Name matches exactly
6. **Partial Name Match** - If Vendor Name contains extracted text (case-insensitive wildcard)
7. **No Match** - User must manually select vendor in preview

### Invoice Line Creation

- If AI extracted lines: Create one Purchase Line per extracted line
- If no lines extracted: Create one line with total amount
- All lines use Default G/L Account from setup
- User can modify G/L Account after creation

### Duplicate Detection

Before creating invoice, system checks:
- Open Purchase Invoices (by Vendor No. + Vendor Invoice No.)
- Posted Purchase Invoices (by Vendor No. + Vendor Invoice No.)

If duplicate found: Error message displayed, creation blocked.

## Future Roadmap

### Version 2.0

- **Azure File Storage Import** - Connect to Azure File Storage for automated invoice import
- **Multi-page PDF support** - Process all pages from multi-page PDFs
- Confidence scoring per extracted field
- Highlight low-confidence fields for review
- Configurable field mapping for non-standard invoices
- Email integration (monitor inbox for invoice attachments)

### Version 3.0

- Azure Document AI as alternative provider
- Machine learning for vendor auto-matching
- Historical pattern learning for GL account suggestions
- Integration with Continia Document Capture (optional)
- Mobile app for camera capture
- Automatic approval for high-confidence extractions

## Development Team

- **Solution Architect:** [Name]
- **AL Developer:** [Name]
- **Functional Consultant:** [Name]
- **Test Lead:** [Name]

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-03-10 | Initial release |
| 1.0.0.10 | 2024-03-12 | Fixed SecretText field types, Media handling, Try/Catch syntax |
| 1.0.0.11 | 2024-03-12 | Fixed URL construction for API calls |
| 1.0.0.12 | 2024-03-12 | Replaced Tenant Media with Image Blob for license compliance |
| 1.0.0.13 | 2024-03-12 | Fixed Base64 conversion, added better error messages |
| 1.0.0.14 | 2024-03-12 | Added "Created Invoices" counter, removed Upload Images section |
| 1.0.0.15 | 2024-03-12 | Locked preview for created invoices, added View Created Invoice action |
| 1.0.0.24 | 2026-03-15 | Added PDF support via Gotenberg conversion service |
| 1.0.2.0 | 2026-03-15 | PaperTide branding, Auto Coding feature, GL Suggestion Confidence, Configurable Concurrency |

---

**Document Version:** 1.3
**Last Updated:** 2026-03-15
