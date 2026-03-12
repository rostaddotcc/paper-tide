# AI Invoice Extractor - Project Documentation

## Project Overview

**Project Name:** AI Invoice Extractor  
**Type:** Per-Tenant Extension (PTE)  
**Version:** 1.0.0.0  
**Target Platform:** Microsoft Dynamics 365 Business Central  
**Minimum Version:** 2024 Release Wave 2 (v27.4)  
**Runtime Version:** 14.0  

## Purpose

Automate the creation of purchase invoices in Business Central by extracting data from invoice images using Alibaba Cloud's Qwen-VL AI vision model. The solution provides a preview workflow where users can review and edit AI-extracted data before committing to the database.

## Business Value

- **Time Savings:** Reduce manual data entry time by 80%+
- **Accuracy:** Minimize typos and data entry errors
- **Audit Trail:** Original image attached to preview for verification
- **Flexibility:** Configurable to work with various invoice formats
- **Integration:** Native Business Central experience

## Scope

### In Scope (v1.0)

- **Batch Import** - Upload multiple invoice images with queue management
- **Concurrency Control** - Process up to 3 images simultaneously
- **Import Queue** - Review and manage all imported documents in a list
- AI extraction via Qwen-VL API
- Preview page with original image display
- Manual review and editing capability
- Creation of standard Purchase Invoices
- Configuration page for API settings
- System prompt customization
- Default G/L Account for invoice lines

### Out of Scope (v1.0)

- PDF file support (planned for v2.0)
- Automatic vendor matching beyond exact name lookup
- Multi-language OCR optimization
- Mobile device camera integration
- Automatic GL account assignment
- VAT calculation validation

## Architecture Decisions

### Why Qwen-VL?

- Strong vision capabilities for document understanding
- Competitive pricing
- JSON-structured output support
- Good performance on invoice documents

### Why Not PDF Support in v1.0?

- Business Central AL has no built-in PDF rendering capability
- External PDF conversion requires additional service (Azure Function, etc.)
- Users can convert PDF to image using standard tools
- Reserved for v2.0 when additional infrastructure is available

### Why Temporary Table for Preview?

- No database persistence until user confirms
- Easy to discard and restart
- Supports complex field editing
- Can display in standard page framework

## Object Catalog

### Tables

| ID | Name | Type | Records |
|----|------|------|---------|
| 50100 | AI Extraction Setup | Singleton | 1 |
| 50101 | Temp Invoice Buffer | Temporary | Session-only |
| 50102 | Import Document Header | Persistent | One per uploaded image |
| 50103 | Import Document Line | Persistent | Invoice lines per document |

### Pages

| ID | Name | Type | Source Table |
|----|------|------|--------------|
| 50100 | AI Extraction Setup | Card | AI Extraction Setup |
| 50101 | Invoice Preview | Card | Import Document Header |
| 50102 | Invoice Preview Subform V2 | ListPart | Import Document Line |
| 50103 | Invoice Image FactBox V2 | CardPart | Import Document Header |
| 50104 | Batch Upload | Card | - |
| 50105 | Import Document List | List | Import Document Header |

### Codeunits

| ID | Name | Access | Purpose |
|----|------|--------|---------|
| 50100 | Qwen VL API | Internal | HTTP communication with AI service |
| 50101 | Invoice Extraction | Internal | JSON parsing and invoice creation |
| 50102 | Batch Processing Mgt | Internal | Queue management and concurrency control |
| 50103 | Batch API Worker | Internal | Individual document processing |

### Page Extensions

| ID | Name | Extends |
|----|------|---------|
| 50100 | Purch. Invoice List Ext | Purchase Invoices |

### Permission Sets

| ID | Name | Permissions |
|----|------|-------------|
| 50100 | AI Invoice Extractor | Full access to all objects |

## Workflow

### 1. Upload Workflow (Batch Upload)

```
User clicks "Batch Upload Invoices" action
    ↓
"Select Files" button opens file dialog
    ↓
User selects one or more images (JPG/JPEG/PNG)
    ↓
For each file:
    - Validate file extension
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
    - Call Qwen-VL API
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
│  - Extension validation (JPG, JPEG, PNG)                         │
│  - MIME type detection                                           │
│  - Save to Image Blob field                                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BATCH PROCESSING                            │
│  Batch Processing Mgt Codeunit                                   │
│  - Queue management with concurrency control (max 3)             │
│  - Status tracking: Pending → Processing → Ready/Error           │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AI SERVICE CALL                             │
│  Qwen VL API Codeunit                                            │
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
│  Invoice Extraction Codeunit                                     │
│  - Map JSON fields to Import Document fields                     │
│  - Vendor lookup:                                                │
│    1. By Vendor No. (exact match)                                │
│    2. By Vendor Name (exact match)                               │
│    3. By Vendor Name (partial match with @*...*)                 │
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
│  Invoice Extraction Codeunit.CreateInvoiceFromImportDoc          │
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
| File Upload | Whitelist validation (JPG/JPEG/PNG only) |
| Data Classification | CustomerContent for all setup data |
| Permissions | Dedicated permission set |

## Configuration Reference

### AI Extraction Setup Fields

| Field | Data Type | Default | Valid Range |
|-------|-----------|---------|-------------|
| API Base URL | Text[250] | - | Valid HTTPS URL |
| API Key | SecretText | - | Non-empty |
| Model Name | Text[50] | qwen-vl-max | Any valid model |
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

1. **No PDF Support** - Users must convert PDFs to images externally (planned for v2.0 with direct PDF-to-base64 conversion)
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

1. **Exact Vendor No.** - If extracted VendorNo matches a Vendor record
2. **Exact Name Match** - If Vendor Name matches exactly
3. **Partial Name Match** - If Vendor Name contains extracted text (case-insensitive)
4. **No Match** - User must manually select vendor in preview

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
- **PDF Support** - Convert PDF to base64 and send directly to Qwen-VL for processing (no external conversion service needed)
- Confidence scoring per extracted field
- Highlight low-confidence fields for review
- Configurable field mapping for non-standard invoices
- Multi-page invoice support
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

---

**Document Version:** 1.1  
**Last Updated:** 2024-03-12
