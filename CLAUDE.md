# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Publish Commands

```bash
# Download symbols (VS Code command palette)
Ctrl+Shift+B        # Build extension
Ctrl+F5             # Publish to sandbox
```

## Architecture Overview

**Type:** Business Central Per-Tenant Extension (AL Language)
**Runtime:** 14.0, requires BC 27.4+
**Object ID Range:** 50100-50149
**Feature:** `NoImplicitWith` enabled

This extension extracts invoice data from images/PDFs using AI vision models (any OpenAI-compatible API) with a preview/approval workflow before creating Purchase Invoices. Includes fraud detection via cross-validation of extracted data against known vendor records.

### Core Flow

```
Upload Image/PDF → (PDF: buffer original + Gotenberg conversion) → Batch Queue → AI Vision API → Parse JSON → Vendor Lookup → Verify → Preview → Create Purchase Invoice
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `PaperTide AI Setup` (Table 50100) | Singleton config: API URL, Key, Model, Default G/L Account |
| `PaperTide Import Doc. Header/Line` | Persistent queue for batch processing |
| `PaperTide Vendor Name Mapping` (Table 50104) | Learned vendor name aliases for automatic matching |
| `PaperTide AI Vision API` (Codeunit 50100) | HTTP client for AI service |
| `PaperTide Invoice Extraction` (Codeunit 50101) | JSON parsing, vendor lookup, verification, invoice creation |
| `PaperTide Batch Processing Mgt` (Codeunit 50102) | Concurrency control (max 3 concurrent) |
| `PaperTide PDF Converter` (Codeunit 50104) | PDF-to-image conversion via Gotenberg |
| `PaperTide GL Account Predictor` (Codeunit 50106) | GL account classification via text AI |
| `PaperTide Invoice Preview` (Page 50101) | Review/edit extracted data with fraud detection and image FactBox |
| `PaperTide Vendor Mappings` (Page 50106) | Manage vendor name alias mappings |

### Status Flow

```
Pending → Processing → Ready → Created
                        ↓
                     Error (retryable)
```

## Key Conventions

- **Codeunits:** `Access = Internal` by default
- **API Keys:** Use `SecretText` data type (encrypted at rest)
- **Error Handling:** Define error messages as global labels with `Lbl` suffix
- **Try-Catch:** Use for external API calls, mark as Error status on failure
- **Validation:** Check setup (API URL, Key, Model) before API calls
- **Duplicate Detection:** Block invoice creation if Vendor Invoice No. already exists
- **Fraud Detection:** Cross-validate extracted VAT/bank data against vendor records

## Object Structure

### Tables
- 50100: PaperTide AI Setup (singleton)
- 50101: PaperTide Temp Invoice Buffer (temporary, preview only)
- 50102: PaperTide Import Doc. Header (persistent queue)
- 50103: PaperTide Import Doc. Line (line items)
- 50104: PaperTide Vendor Name Mapping (learned vendor aliases)

### Codeunits
- 50100: PaperTide AI Vision API (HTTP communication)
- 50101: PaperTide Invoice Extraction (parsing, vendor lookup, verification, creation logic)
- 50102: PaperTide Batch Processing Mgt (queue management)
- 50103: PaperTide Batch API Worker (individual processing)
- 50104: PaperTide PDF Converter (Gotenberg PDF-to-image)
- 50106: PaperTide GL Account Predictor (GL account classification via text AI)

### Pages
- 50100: PaperTide AI Setup
- 50101: PaperTide Invoice Preview (with subform + image FactBox + fraud detection)
- 50104: PaperTide Batch Upload
- 50105: PaperTide Import Documents
- 50106: PaperTide Vendor Mappings

### Enums
- 50100: PaperTide Import Doc. Status (Pending, Ready, Created, Discarded)
- 50101: PaperTide Import Proc. Status (Pending, Processing, Completed, Error)
- 50102: PaperTide Inv. Verif. Status (Not Checked, Verified, Warning, Suspicious)

### Permission Sets
- 50100: PaperTide

### Page Extensions
- 50100: PaperTide Purch. Inv. List Ext

## File Organization

```
API/                 # PaperTide AI Vision API, Invoice Extraction, PDF Converter, GL Account Predictor codeunits
BatchProcessing/     # Queue management, upload UI, import documents, preview pages
InvoiceProcessing/   # Temp buffer, preview subforms
Pages/               # Purchase Invoice list extension
Setup/               # PaperTide AI Setup table/page, Vendor Name Mapping table/page
```

## Vendor Matching (LookupVendorNoExtended)

Matching priority:
1. Vendor Name Mapping table (learned aliases, exact match)
2. Exact vendor number from AI
3. VAT Registration No. against Vendor."VAT Registration No."
4. Bank Account/IBAN against Vendor Bank Account records
5. Exact name match against Vendor.Name
6. Wildcard partial name match

## Vendor Name Learning

When user changes Vendor No. in Invoice Preview and the AI-extracted name differs from the actual vendor name, a mapping is saved to `PaperTide Vendor Name Mapping` table. On subsequent imports, the mapping is checked first (step 1 in lookup). Usage count is tracked per mapping.

## Fraud Detection (VerifyVendorData)

Runs automatically after AI extraction in `ParseAndSaveToImportDoc`. Cross-validates:
- Extracted VAT No. vs Vendor."VAT Registration No." → Suspicious if mismatch
- Extracted Bank Account vs registered Vendor Bank Account IBAN/No. → Suspicious if unknown
- Missing vendor match → Warning
- Missing VAT/bank on invoice → Warning (cannot verify)
- All matches → Verified

Users can manually re-run via "Verify" action in PaperTide Invoice Preview. Suspicious invoices require explicit confirmation before creation.

## AI GL Account Suggestion

When enabled, the system:
1. Caches chart of accounts (max 100 posting accounts) via "Refresh Chart of Accounts"
2. Sends account list to AI in system prompt
3. AI returns `GLAccountNo` per line in JSON response
4. Falls back to Default G/L Account if AI returns empty/invalid

## AI JSON Schema

The AI extracts and returns:
- Header: VendorNo, VendorName, VendorVATNo, VendorBankAccount, InvoiceNo, InvoiceDate, DueDate, AmountInclVAT, AmountExclVAT, VATAmount, CurrencyCode, PONumber
- Lines: Description, Quantity, UnitPrice, Amount, GLAccountNo

## PDF Handling

### Upload Flow
```
Upload PDF → Buffer original in TempBlob → Convert page 1 to PNG via Gotenberg → Store PNG as Image Blob + Original PDF as "Original PDF Blob"
```

### Attachment
When creating Purchase Invoice, the original PDF (all pages) is attached as Document Attachment. Falls back to PNG if no original PDF stored.

### Gotenberg API
- **Endpoint:** `{PDF Converter Endpoint}/forms/chromium/screenshot/html`
- **Method:** POST multipart/form-data
- **Parts:** `files` (HTML with inline base64 PDF + pdf.js renderer), `format` (png), `waitForExpression` (window.pdfRendered===true)
- **Returns:** PNG image of first page at 3x scale

### Configuration
- `Enable PDF Conversion`: Boolean toggle
- `PDF Converter Endpoint`: Base URL (e.g., `https://pdf.rostad.cc`)

## HTTP Integration Pattern

All external API calls follow this pattern:
1. Validate setup (API URL, Key, Model not empty)
2. Build JSON request body (model, messages, max_tokens, temperature)
3. Set HTTP headers: `Authorization: Bearer {API Key}`, `Content-Type: application/json`
4. Handle timeout (configurable, default 60s)
5. Parse JSON response, handle markdown formatting (` ```json ... ``` `)
6. Catch errors, set status to Error with message

## Testing

See `TEST-GL-SUGGESTION.md` for AI GL Account Suggestion test plan.
