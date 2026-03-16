# Paper Tide - Project Documentation

## Project Overview

**Project Name:** Paper Tide
**Type:** Per-Tenant Extension (PTE)
**Version:** 1.1.0.0
**Target Platform:** Microsoft Dynamics 365 Business Central
**Minimum Version:** 2024 Release Wave 2 (v27.4)
**Runtime Version:** 14.0

## Purpose

Automate the creation of purchase invoices in Business Central by extracting data from invoice images using AI vision models (any OpenAI-compatible API). The solution provides a preview workflow where users can review AI-extracted data, auto-coded accounts, items and dimensions before committing to the database.

## Business Value

- **Time Savings:** Reduce manual data entry time by 80%+
- **Accuracy:** Minimize typos and data entry errors
- **Smart Classification:** AI learns from posting history to suggest accounts, items, and dimensions
- **Audit Trail:** Original image attached to preview for verification
- **Flexibility:** Configurable to work with various invoice formats and AI providers
- **Integration:** Native Business Central experience
- **Security:** API keys encrypted in Isolated Storage, not stored in plain text

## Scope

### In Scope (v1.1)

- **Batch Import** - Upload multiple invoice images with queue management
- **Concurrency Control** - Process up to 10 images simultaneously (configurable)
- **Import Queue** - Review and manage all imported documents in a list
- AI extraction via OpenAI-compatible vision API
- Preview page with original image display
- Manual review and editing capability
- Creation of standard Purchase Invoices
- Configuration page for API settings
- System prompt customization
- Default G/L Account for invoice lines
- **AI GL Account Suggestion** - AI analyzes chart of accounts and suggests appropriate G/L accounts per line
- **Auto Coding** - Separate text AI model for account/item classification with confidence scoring and dimension suggestions
- **Item Classification** - AI suggests Items in addition to G/L Accounts
- **Dimension Suggestions** - AI suggests Global Dimension 1 & 2 values based on posting history
- **Editable Dimensions** - Review and edit dimension values in preview before invoice creation
- **Vendor Name Learning** - Learned vendor name aliases for automatic matching on subsequent imports
- **Multi-Field Vendor Matching** - Match vendors by name mapping, vendor no., VAT no., bank account/IBAN, exact name, or partial name
- **Fraud Detection** - Cross-validate extracted VAT/bank data against known vendor records
- **Secure API Key Storage** - Isolated Storage with per-company encryption and auto-migration

### Out of Scope (v1.1)

- Multi-language OCR optimization
- Mobile device camera integration
- VAT calculation validation
- Per-vendor auto coding configuration

## Architecture Decisions

### Why OpenAI-Compatible API?

- Provider-agnostic: works with OpenAI, DashScope, Azure OpenAI, Groq, Ollama, etc.
- Strong vision capabilities for document understanding
- JSON-structured output support
- Built-in provider presets for quick setup

### Why Isolated Storage for API Keys?

- Encrypted at rest by the Business Central platform
- Per-company isolation (each company has its own keys)
- Not included in database backups (unlike table fields)
- Auto-migration from legacy plain-text fields on first access
- Same UX pattern as BC's built-in credential storage

### PDF Conversion via Gotenberg

- Business Central AL has no built-in PDF rendering capability
- PDF files are converted to PNG images at upload time via external Gotenberg service
- Gotenberg uses Chromium + pdf.js to render PDF pages as high-quality images
- All pages are rendered and stacked vertically into a single image for AI processing

### Two-Stage AI Classification

1. **Vision Model** - Extracts raw invoice data (vendor, amounts, line descriptions) from the image
2. **Coding Model** (Auto Coding) - Classifies lines against chart of accounts, items, and dimensions with full posting history context

This separation allows:
- Using a cheaper/faster text model for classification
- Including much more context (item list, dimension values, posting history) without image token overhead
- Running classification as a separate retry-able step

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
| 50103 | PaperTide Import Doc. Line | Persistent | Invoice lines per document (with dimensions) |
| 50104 | PaperTide Vendor Name Mapping | Persistent | Learned vendor name aliases |

**AI Extraction Setup Fields:**
- API Base URL, API Key (Isolated Storage), Model Name
- Max Tokens, Temperature, Request Timeout
- Default G/L Account
- **Enable AI GL Suggestion** - Activates AI-powered G/L account suggestions (vision model mode)
- **Chart of Accounts Context** - Cached G/L accounts for AI context
- **Enable PDF Conversion** - Activates PDF upload with automatic image conversion
- **PDF Converter Endpoint** - Gotenberg service URL
- **Auto Coding** - Separate text AI model connection, system prompt, history settings

**Import Doc. Line Fields:**
- Type (G/L Account, Item), No., Description, Quantity, Unit Price, Line Amount, VAT %
- Shortcut Dimension 1 Code, Shortcut Dimension 2 Code (editable, with lookup)
- Dimension Suggestion (full AI suggestion text)
- GL Suggestion Confidence (High/Medium/Low), GL Suggestion Reason

### Pages

| ID | Name | Type | Source Table |
|----|------|------|--------------|
| 50100 | PaperTide AI Setup | Card | PaperTide AI Setup |
| 50101 | PaperTide Invoice Preview | Card | PaperTide Import Doc. Header |
| 50102 | PaperTide Inv. Preview Subform | ListPart | PaperTide Import Doc. Line |
| 50103 | PaperTide Inv. Image FactBox | CardPart | PaperTide Import Doc. Header |
| 50105 | PaperTide Import Documents | List | PaperTide Import Doc. Header |
| 50106 | PaperTide Vendor Mappings | List | PaperTide Vendor Name Mapping |

### Codeunits

| ID | Name | Access | Purpose |
|----|------|--------|---------|
| 50100 | PaperTide AI Vision API | Internal | HTTP communication with AI service |
| 50101 | PaperTide Invoice Extraction | Internal | JSON parsing, vendor lookup, verification, invoice creation with dimensions |
| 50102 | PaperTide Batch Processing Mgt | Internal | Queue management and concurrency control |
| 50103 | PaperTide Batch API Worker | Internal | Individual document processing with auto coding status logging |
| 50104 | PaperTide PDF Converter | Internal | PDF-to-image conversion via Gotenberg |
| 50106 | PaperTide GL Account Predictor | Internal | Account, item, and dimension classification via text AI model |

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

## Auto Coding Feature

### Overview
The Auto Coding feature uses a separate text AI model to classify invoice lines against your chart of accounts, item list, and dimension values. It considers posting history from the same vendor to make consistent suggestions.

### How It Works

1. **Context Building**
   - Cached chart of accounts (with categories and subcategories)
   - Item list (with item category codes)
   - Available dimension values (Global Dimension 1 & 2 from General Ledger Setup)
   - Posting history: recent posted invoices from the same vendor (lines, accounts, types, dimensions)

2. **Classification**
   - AI classifies each line as G/L Account or Item
   - Suggests the best matching number from the provided lists
   - Suggests dimension values based on posting patterns
   - Returns confidence level and reasoning

3. **Application**
   - Validates suggested accounts/items exist and are not blocked
   - Maps dimension suggestions to Shortcut Dimension 1 & 2 (validated)
   - Falls back to index-based line matching if AI returns wrong LineNo
   - Logs detailed status summary to Import Document Header

4. **Review**
   - User sees Type, No., dimensions, confidence, and reason per line
   - All fields are editable in the preview
   - Can re-run classification via "Suggest Accounts" action
   - Dimensions applied to Purchase Lines when invoice is created

### Fallback & Error Handling

| Scenario | Behavior |
|----------|----------|
| AI returns wrong LineNo | Falls back to array index matching, marks with "[Matched by index]" |
| Suggested account doesn't exist | Line keeps default, confidence/reason still shown |
| Suggested dimension value is blocked | Dimension not applied, but shown in Dimension Suggestion text |
| API call fails | Status logged: "Auto Coding: API call failed" |
| JSON parse fails | Status logged: "Auto Coding: Failed to parse AI response" |
| TryFunction catches error | Error text saved to Auto Coding Status field |

## Security

| Aspect | Implementation |
|--------|---------------|
| API Key Storage | Isolated Storage (encrypted at rest, per-company, auto-migrated) |
| Storage Keys | `PaperTide_APIKey`, `PaperTide_CodingAPIKey`, `PaperTide_PDFConverterAPIKey` |
| Migration | Automatic: old Text[250] fields → Isolated Storage on first `GetOrCreateSetup()` |
| UI Display | Masked fields with `***` indicator when key exists |
| HTTP Security | HTTPS only (enforced by URL validation) |
| File Upload | Whitelist validation (JPG/JPEG/PNG/PDF) |
| Data Classification | CustomerContent for business data, EndUserIdentifiableInformation for API keys |
| Permissions | Dedicated permission set |

## Configuration Reference

### AI Extraction Setup Fields

| Field | Data Type | Default | Valid Range |
|-------|-----------|---------|-------------|
| API Base URL | Text[250] | - | Valid HTTPS URL |
| API Key | Isolated Storage | - | Non-empty |
| Model Name | Text[50] | - | Any valid vision model |
| Max Tokens | Integer | 2048 | 100-4096 |
| Temperature | Decimal | 0.1 | 0.0-2.0 |
| Request Timeout | Integer | 60000 | 10000-300000 |
| Max Concurrency | Integer | 3 | 1-10 |
| Processing Timeout (min) | Integer | 5 | 0-60 |
| System Prompt | Blob | Default prompt | Any valid text |
| Coding API Base URL | Text[250] | - | Valid HTTPS URL |
| Coding API Key | Isolated Storage | - | Non-empty |
| Coding Model Name | Text[50] | - | Any valid text model |
| Coding Max Tokens | Integer | 1024 | 100-4096 |
| Coding Temperature | Decimal | 0.0 | 0.0-2.0 |
| Chart Context Max Accounts | Integer | 200 | 10-1000 |
| Coding History Invoices | Integer | 10 | 0-50 |
| Coding History Days | Integer | 0 | 0-3650 |

## Workflow

### 1. Upload Workflow

```
User clicks "PaperTide Upload" in Purchase Invoices toolbar
    |
File dialog opens immediately
    |
User selects one or more files (JPG/JPEG/PNG/PDF)
    |
For each file:
    - Validate file extension
    - If PDF: buffer original + convert to PNG via Gotenberg
    - Save image to Image Blob field
    - Create Import Document Header record
    - Set status to "Pending"
    |
Auto-start processing if concurrency available
```

### 2. Processing Workflow (Background)

```
Batch Processing Mgt checks for pending documents
    |
If concurrency slot available:
    - Start Batch API Worker
    - Set status to "Processing"
    |
Batch API Worker:
    - Read image from Image Blob -> Convert to Base64
    - Call AI Vision API -> Parse JSON response
    - Save extracted data to Import Document Header/Line
    - Run Auto Coding (if enabled):
        - Build context: chart of accounts + items + dimensions + history
        - Call Coding AI -> Parse classification response
        - Apply accounts, items, dimensions to lines
        - Log Auto Coding Status
    - Set status to "Ready" (success) or "Error" (failure)
    |
Process next pending document if available
```

### 3. Review & Approval Workflow

```
User opens "Import Document Queue"
    |
Select document with status "Ready"
    |
"Review & Edit" opens Invoice Preview page
    |
User can:
    - View extracted data + auto coding results
    - Edit fields, dimensions, accounts (toggle edit mode)
    - View original image in FactBox
    - Re-run "Suggest Accounts" for updated classification
    - Re-run "Verify" for fraud checks
    - Click "Accept & Create Invoice"
    |
System validates:
    - Vendor No. is specified
    - Invoice No. is specified
    - No duplicate vendor invoice no.
    |
Create Purchase Invoice:
    - Create Purchase Header
    - Create Purchase Lines (with Type, No., dimensions from preview)
    - Attach original PDF or image as Document Attachment
    - Update Import Document status to "Created"
    |
Open created Purchase Invoice
```

## Business Logic

### Invoice Line Creation

- If AI extracted lines: Create one Purchase Line per extracted line
- Line Type and No. from Auto Coding (G/L Account or Item)
- If no No. specified: Use Default G/L Account from setup
- Shortcut Dimension 1 & 2 applied from preview values
- If no lines extracted: Create one line with total amount
- User can modify all values in Preview before creation

### Duplicate Detection

Before creating invoice, system checks:
- Open Purchase Invoices (by Vendor No. + Vendor Invoice No.)
- Posted Purchase Invoices (by Vendor No. + Vendor Invoice No.)

If duplicate found: Error message displayed, creation blocked.

### Vendor Matching Logic

1. **Vendor Name Mapping** - Learned aliases from previous user corrections (exact match)
2. **Exact Vendor No.** - If extracted VendorNo matches a Vendor record
3. **VAT Registration No.** - Match extracted VAT No. against Vendor."VAT Registration No."
4. **Bank Account/IBAN** - Match extracted bank account against registered Vendor Bank Account records
5. **Exact Name Match** - If Vendor Name matches exactly
6. **Partial Name Match** - If Vendor Name contains extracted text (case-insensitive wildcard)
7. **No Match** - User must manually select vendor in preview

## Testing Checklist

### Unit Testing

- [ ] API connection test returns success with valid credentials
- [ ] API connection test fails with invalid credentials
- [ ] Image to Base64 conversion works correctly
- [ ] JSON response parsing handles valid responses
- [ ] JSON response parsing handles malformed responses
- [ ] Date parsing works for ISO 8601 format
- [ ] Vendor lookup by number, VAT, bank, name works
- [ ] Auto Coding classifies lines with valid accounts
- [ ] Auto Coding handles invalid accounts gracefully
- [ ] Auto Coding suggests dimensions from posting history
- [ ] Isolated Storage set/get/has/delete operations
- [ ] Auto-migration of plain-text keys to Isolated Storage
- [ ] Dimension values validated against Dimension Value table

### Integration Testing

- [ ] Full flow: Upload -> Extract -> Auto Code -> Preview -> Create
- [ ] Invoice creation with dimensions applied to purchase lines
- [ ] Invoice creation with Item type lines
- [ ] Auto Coding status logged on header
- [ ] Fallback index matching when AI returns wrong LineNo
- [ ] Edit mode allows dimension modification before creation
- [ ] Duplicate invoice detection works
- [ ] Error handling for network failures

### User Acceptance Testing

- [ ] Auto Coding results visible and understandable
- [ ] Dimension columns visible and editable in preview
- [ ] Confidence styling (green/yellow/red) is clear
- [ ] Workflow feels natural to AP clerks

## Known Limitations

1. **No Auto-Post** - Invoices created as open, not posted
2. **Two Shortcut Dimensions** - Only Global Dimension 1 & 2 supported in preview (additional dimensions possible via Dimension Set after creation)
3. **Single Currency** - Currency must be specified; no automatic detection
4. **Manual Upload Only** - No automated import from cloud storage or email (planned)
5. **No Per-Vendor Coding Config** - All vendors use the same auto coding settings (planned)

## Future Roadmap

### Version 1.2 (Planned)

- **Vendor Auto Coding Setup** - Per-vendor configuration for auto coding preferences: default line type, preferred G/L accounts, dimension defaults, classification rules
- **Email Inbox Monitoring** - REST-based email endpoint for automatic attachment import with job queue
- **Discard Comment** - When discarding an imported invoice, prompt for a comment/reason that is stored and visible in the Import Documents queue list

### Version 2.0

- **Purchase Order Matching** - Link invoices to existing POs via extracted PO number
- **VIES VAT Validation** - EU VAT number validation at import
- **Azure File Storage Import** - Automated import from cloud storage
- Confidence scoring per extracted field
- Configurable field mapping for non-standard invoices

### Version 3.0

- Azure Document AI as alternative provider
- Mobile app for camera capture
- Automatic approval for high-confidence extractions

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
| 1.0.2.1 | 2026-03-15 | Multi-page PDF support: all pages rendered for AI extraction |
| 1.0.2.2 | 2026-03-16 | Inline file upload from Purchase Invoices toolbar, stuck document recovery |
| 1.1.0.0 | 2026-03-16 | Isolated Storage for API keys, Auto Coding with item + dimension support, editable dimensions in preview |

---

**Document Version:** 2.0
**Last Updated:** 2026-03-16
