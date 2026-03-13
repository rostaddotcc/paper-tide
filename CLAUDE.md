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

This extension extracts invoice data from images using Qwen-VL AI with a preview/approval workflow before creating Purchase Invoices.

### Core Flow

```
Upload Image → Batch Queue → Qwen-VL API → Parse JSON → Preview → Create Purchase Invoice
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `AI Extraction Setup` (Table 50100) | Singleton config: API URL, Key, Model, Default G/L Account |
| `Import Document Header/Line` | Persistent queue for batch processing |
| `Qwen VL API` (Codeunit 50100) | HTTP client for AI service |
| `Invoice Extraction` (Codeunit 50101) | JSON parsing, vendor lookup, invoice creation |
| `Batch Processing Mgt` (Codeunit 50102) | Concurrency control (max 3 concurrent) |
| `Invoice Preview` (Page 50101) | Review/edit extracted data with image FactBox |

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

## Object Structure

### Tables
- 50100: AI Extraction Setup (singleton)
- 50101: Temp Invoice Buffer (temporary, preview only)
- 50102: Import Document Header (persistent queue)
- 50103: Import Document Line (line items)

### Codeunits
- 50100: Qwen VL API (HTTP communication)
- 50101: Invoice Extraction (parsing, creation logic)
- 50102: Batch Processing Mgt (queue management)
- 50103: Batch API Worker (individual processing)

### Pages
- 50100: AI Extraction Setup Card
- 50101: Invoice Preview (with subform + image FactBox)
- 50104: Batch Upload
- 50105: Import Document List

## File Organization

```
API/                 # QwenVLAPI, Invoice Extraction codeunits
BatchProcessing/     # Queue management, upload UI, import documents
InvoiceProcessing/   # Temp buffer, preview pages
Pages/               # Purchase Invoice list extension
Setup/               # AI Extraction Setup table/page
```

## AI GL Account Suggestion

When enabled, the system:
1. Caches chart of accounts (max 100 posting accounts) via "Refresh Chart of Accounts"
2. Sends account list to AI in system prompt
3. AI returns `GLAccountNo` per line in JSON response
4. Falls back to Default G/L Account if AI returns empty/invalid

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
