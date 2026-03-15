# Paper Tide for Business Central

A Per-Tenant Extension (PTE) for Business Central that uses AI vision models to extract invoice data from images and PDF files, with a preview and approval workflow. Compatible with any OpenAI-compatible API (OpenAI, DashScope, Azure OpenAI, Groq, Ollama, etc.).

## Features

- **AI-Powered OCR** - Extract invoice data using any OpenAI-compatible vision model
- **PDF Support** - Upload PDF invoices with automatic conversion to images via Gotenberg
- **Multi-Page PDF Attachment** - Original PDF (all pages) attached to created Purchase Invoice
- **Batch Import** - Upload and process multiple invoice images/PDFs simultaneously
- **Concurrency Control** - Process up to 3 images at once with automatic queue management
- **Import Queue** - View and manage all imported documents with status tracking
- **Preview & Edit** - Review extracted data with original image in FactBox before creating
- **AI GL Account Suggestion** - AI analyzes your chart of accounts and suggests the most appropriate G/L account for each invoice line
- **Auto Coding (Separate AI Model)** - Dedicated text AI model for GL account classification with confidence levels and reasoning
- **PO Number Extraction** - AI extracts purchase order references from invoices
- **Vendor Name Learning** - System learns vendor name aliases from user corrections for automatic future matching
- **Multi-Field Vendor Matching** - Match vendors by VAT Registration No., bank account/IBAN, name mapping, or name
- **Fraud Detection** - Automated verification of VAT numbers and bank accounts against known vendor data
- **Provider Agnostic** - Built-in presets for OpenAI, DashScope, Azure OpenAI, Groq, Ollama, LocalAI
- **Configurable** - Set up your own API endpoint, model, system prompt, and default G/L account
- **Secure** - API keys stored with masked display
- **Status Tracking** - Track documents from Pending -> Processing -> Ready -> Created
- **Duplicate Detection** - Prevent duplicate vendor invoice numbers

## Requirements

- Business Central 2024 Wave 2 (v27.4) or later
- AI vision API access (any OpenAI-compatible provider: OpenAI, DashScope, Azure OpenAI, Groq, Ollama, etc.)
- Gotenberg service (for PDF support, optional)
- AL Language extension for VS Code

## Installation

### 1. Clone/Copy the Project

```bash
cd AIInvoiceExtractor
```

### 2. Download Symbols

In VS Code:
- Press `Ctrl+Shift+P`
- Select `AL: Download symbols`
- Ensure your `launch.json` is configured (see below)

### 3. Build the Extension

- Press `Ctrl+Shift+B` to build
- Or run: `alc /project:. /packagecachepath:./.alpackages`

### 4. Publish

- Press `Ctrl+F5` to publish to your sandbox
- Or use: `AL: Publish` command

## Configuration

After publishing, configure the extension:

1. Search for **"PaperTide AI Setup"** in Business Central
2. Fill in the following fields:

| Field | Example Value | Description |
|-------|---------------|-------------|
| API Base URL | `https://api.openai.com/v1` | AI API endpoint (OpenAI-compatible) |
| API Key | `sk-xxxxxxxx` | Your API key from your AI provider |
| Model Name | `gpt-4o` | Vision model identifier |
| Max Tokens | `2048` | Response length limit |
| Temperature | `0.1` | AI creativity (0.0 = strict) |
| Request Timeout | `60000` | API request timeout in milliseconds |
| Default G/L Account | `6110` | Default G/L account for invoice lines |
| Enable AI GL Suggestion | `Yes` | Let AI suggest G/L accounts based on your chart of accounts |
| Enable PDF Conversion | `Yes` | Allow PDF uploads with automatic image conversion |
| PDF Converter Endpoint | `https://pdf.example.com` | Gotenberg service URL |
| System Prompt | *(see below)* | Instructions for data extraction |

### AI GL Account Suggestion

When **Enable AI GL Suggestion** is activated:
1. Click **Refresh Chart of Accounts** to cache your G/L accounts
2. The AI will analyze each invoice line description
3. Based on your chart of accounts, AI suggests the most appropriate G/L account
4. If AI cannot determine a match, the Default G/L Account is used as fallback
5. You can always review and edit the suggested accounts in the Preview page

### Vendor Name Mappings

The system learns from your corrections:
1. AI extracts vendor name "hej AB" from an invoice
2. You manually select vendor "Hejsan AB" in the preview
3. The mapping "hej AB" -> "Hejsan AB" is saved automatically
4. Next time "hej AB" appears, it matches "Hejsan AB" without manual intervention

Manage mappings via **PaperTide AI Setup** -> **PaperTide Vendor Mappings**.

### Default System Prompt

The extension includes a default system prompt that instructs the AI to return JSON in this format:

```json
{
  "VendorNo": "VEND001",
  "VendorName": "Acme Supplies",
  "VendorVATNo": "SE556677889901",
  "VendorBankAccount": "SE1234567890123456",
  "InvoiceNo": "INV-2024-001",
  "InvoiceDate": "2024-03-15",
  "DueDate": "2024-04-15",
  "AmountInclVAT": 12500.00,
  "AmountExclVAT": 10000.00,
  "VATAmount": 2500.00,
  "CurrencyCode": "SEK",
  "PONumber": "PO-2024-100",
  "Lines": [
    {
      "Description": "Consulting services",
      "Quantity": 10,
      "UnitPrice": 1000.00,
      "Amount": 10000.00,
      "GLAccountNo": "6100"
    }
  ]
}
```

*Note: `GLAccountNo` is automatically suggested by AI when AI GL Suggestion is enabled.*

You can customize the system prompt in the setup page to match your specific invoice formats.

## Usage

### Workflow Overview

```
Upload -> Process (AI) -> Verify -> Review -> Create Invoice
```

### 1. Batch Upload

1. Navigate to **Purchase Invoices** page
2. Click **"Batch Upload Invoices"** in the ribbon
3. Click **"Select Files"** button
4. Select one or more JPG/PNG/PDF files (you can upload multiple files in sequence)
5. Files are automatically queued and processed (max 3 concurrent)
6. The **Processing Queue** shows counts: Pending, Processing, Ready for Review, Errors, Created

### 2. Monitor Processing

- **Pending**: Waiting for processing slot
- **Processing**: AI extraction in progress
- **Ready for Review**: Extraction complete, ready for your review
- **Errors**: Processing failed (hover to see error message)
- **Created**: Invoice already created from this document

### 3. Review, Verify & Edit

1. Click **"View Import Queue"** to see all documents
2. Find a document with status **"Ready"**
3. Check the **Verification Status** column for fraud detection results
4. Click **"Review & Edit"** to open **Invoice Preview**
5. Review extracted data:
   - Header fields (Vendor, VAT No., Bank Account, Invoice No, Dates, PO Number, Amounts)
   - Fraud Detection section (Verification Status and messages)
   - Line items in the subform
   - Original image in the FactBox on the right
6. Click **"Edit Values"** to enable editing if corrections are needed
7. Click **"Verify"** to re-run fraud checks after edits
8. Make corrections and fields will auto-save

### 4. Fraud Detection

The system automatically verifies extracted data against known vendor records:

| Check | Result |
|-------|--------|
| VAT No. on invoice matches vendor card | **Verified** |
| VAT No. mismatch | **Suspicious** |
| Bank account not in registered vendor accounts | **Suspicious** |
| Vendor has no VAT/bank on file (can't verify) | **Warning** |
| No vendor match at all | **Warning** |
| No VAT/bank on invoice | **Warning** |

- **Verified** (green) - All checks passed
- **Warning** (yellow) - Needs attention, proceed with confirmation
- **Suspicious** (red) - Strong warning with explicit confirmation required

### 5. Create Invoice

1. After review, click **"Accept & Create Invoice"**
2. If invoice is flagged as Suspicious, an explicit confirmation dialog appears
3. System validates:
   - Vendor No. is specified
   - Invoice No. is specified
   - No duplicate vendor invoice number exists
4. Purchase Invoice is created with:
   - Header data from extracted information
   - PO Number stored as Vendor Order No.
   - Lines from extracted line items (or one line with total if no lines)
   - Original PDF or image attached as Document Attachment
5. Document status changes to **"Created"**
6. Created invoice opens automatically

### 6. Vendor Matching Priority

When the AI extracts vendor information, matching follows this priority:

1. **Vendor Name Mapping** - Previously learned alias (exact match)
2. **Vendor No.** - Direct vendor number from AI
3. **VAT Registration No.** - Match against Vendor."VAT Registration No."
4. **Bank Account / IBAN** - Match against Vendor Bank Account records
5. **Exact Name** - Match against Vendor.Name
6. **Partial Name** - Wildcard match on Vendor.Name

### Supported File Formats

| Format | Status | Notes |
|--------|--------|-------|
| JPG/JPEG | Supported | Direct upload |
| PNG | Supported | Direct upload |
| PDF | Supported | Requires Gotenberg service for conversion |

## Architecture

### Batch Import Flow

```
User selects multiple images/PDFs
        |
[PaperTide Batch Upload] -> Queue files (PDF -> buffer original + Gotenberg -> PNG)
        |
[PaperTide Batch Processing Mgt] -> Concurrency control (max 3)
        |
[PaperTide Batch API Worker] -> Process each image
        |
[PaperTide AI Vision API] -> HTTP POST with base64 image
        |
AI vision model processes image
        |
[PaperTide Invoice Extraction] -> Parse JSON + Vendor Lookup + Verify
        |
Save to Import Document Header + Lines
        |
[PaperTide Import Documents] -> Display with status + verification
        |
User opens PaperTide Invoice Preview -> Review, verify & edit
        |
Create Purchase Header + Lines + Attach PDF/image
        |
Mark Import Document as "Created"
```

### Status Flow

```
Pending -> Processing -> Ready -> Created
   |          |         |
   +----------+---------+-> Error (retryable)
```

| Status | Description |
|--------|-------------|
| **Pending** | Document uploaded, waiting for processing slot |
| **Processing** | AI extraction in progress |
| **Ready** | Extraction complete, ready for review |
| **Created** | Invoice successfully created |
| **Error** | Processing failed, can be retried |
| **Discarded** | Manually discarded by user |

## Technical Details

### ID Ranges

- Tables: 50100-50149
- Pages: 50100-50149
- Codeunits: 50100-50149
- Permission Sets: 50100

### Key Objects

| Object | Type | ID | Purpose |
|--------|------|----|---------|
| PaperTide AI Setup | Table | 50100 | Configuration storage (singleton) |
| PaperTide Temp Invoice Buffer | Table | 50101 | Temporary data for preview |
| PaperTide Import Doc. Header | Table | 50102 | Persistent queue for batch processing |
| PaperTide Import Doc. Line | Table | 50103 | Extracted line items |
| PaperTide Vendor Name Mapping | Table | 50104 | Learned vendor name aliases |
| PaperTide AI Vision API | Codeunit | 50100 | HTTP client for AI service |
| PaperTide Invoice Extraction | Codeunit | 50101 | Parser, vendor lookup, verification, invoice creation |
| PaperTide Batch Processing Mgt | Codeunit | 50102 | Queue and concurrency management |
| PaperTide Batch API Worker | Codeunit | 50103 | Individual document processor |
| PaperTide PDF Converter | Codeunit | 50104 | PDF-to-image conversion via Gotenberg |
| PaperTide GL Account Predictor | Codeunit | 50106 | GL account classification via text AI model |
| PaperTide AI Setup | Page | 50100 | Setup card |
| PaperTide Invoice Preview | Page | 50101 | Review interface with fraud detection and image FactBox |
| PaperTide Inv. Preview Subform | Page | 50102 | Invoice line subform |
| PaperTide Inv. Image FactBox | Page | 50103 | Image preview FactBox |
| PaperTide Batch Upload | Page | 50104 | Multi-file upload interface |
| PaperTide Import Documents | Page | 50105 | Document queue with verification status |
| PaperTide Vendor Mappings | Page | 50106 | Manage vendor name aliases |
| PaperTide Purch. Inv. List Ext | PageExtension | 50100 | Purchase Invoice list extension |
| PaperTide Import Doc. Status | Enum | 50100 | Document status values |
| PaperTide Import Proc. Status | Enum | 50101 | Processing status values |
| PaperTide Inv. Verif. Status | Enum | 50102 | Verification status values |
| PaperTide | PermissionSet | 50100 | Extension permissions |

## Troubleshooting

### "Setup is not configured"
- Go to **PaperTide AI Setup** page (search for it)
- Fill in **API Base URL** and **API Key**
- Fill in **Model Name** (e.g., `gpt-4o`) or use a Provider Preset
- Click **"Test Connection"**

### "HTTP request failed"
- Check your internet connection
- Verify API key is valid and not expired
- Ensure API Base URL is correct (should end with `/v1`)
- Check timeout setting (increase if needed, default 60s)

### "Invalid response from AI service"
- AI response may not be valid JSON
- Check system prompt formatting
- Try with a clearer invoice image
- Check that the image format is JPG or PNG

### "Image Blob is empty"
- The uploaded file may be corrupted
- Try uploading the image again
- Check that the file is not 0 bytes

### "Import document not found"
- The document may have been deleted
- Check the Import Document Queue

### "Invoice already created for this document"
- The document has already been processed
- View the created invoice using "View Created Invoice" action

### Extension won't publish
- Ensure `allowHttpClientRequests` is enabled in extension settings
- In Extension Management, click Configure -> Allow HttpClient Requests

### Cannot see PaperTide AI Setup page
- Ensure you have the **"PaperTide"** permission set assigned
- Go to Users -> select your user -> Permission Sets -> add "PaperTide"

## Changelog

### v1.0.2.0 (2026-03-15)
- **PaperTide Branding** - Full rebrand of all AL objects with PaperTide prefix for consistent naming
- **Auto Coding (Separate AI Model)** - New feature: dedicated text AI model for GL account classification, separate from vision model. Configurable connection, model, and system prompt. Includes vendor posting history context for better predictions.
- **GL Suggestion Confidence** - AI returns confidence level (High/Medium/Low) and reasoning per line suggestion
- **Configurable Concurrency** - Max concurrent processing now configurable in setup (1-10, default 3)
- Fixed syntax issues in AI Setup page and Invoice Preview Subform
- Fixed ActionRef/Promoted property conflicts in Batch Upload page

### v1.0.1.1 (2026-03-15)
- **Provider Agnostic** - Renamed internal API codeunit from Qwen VL API to AI Vision API; removed all provider-specific references
- **Provider Presets** - Built-in quick setup for OpenAI, DashScope (Alibaba), Azure OpenAI, Groq, Ollama, LocalAI
- Generalized tooltips and documentation for multi-provider compatibility

### v1.0.1.0 (2026-03-15)
- **PO Number Extraction** - AI extracts purchase order references from invoices, stored as Vendor Order No.
- **Multi-Page PDF Attachment** - Original PDF (all pages) attached to created Purchase Invoice instead of first-page PNG only
- **Vendor Name Learning** - Automatic alias mapping when user corrects vendor in preview, used for future matching
- **Multi-Field Vendor Matching** - Match by VAT Registration No., bank account/IBAN, name mapping, in addition to name
- **Fraud Detection** - Automated cross-validation of extracted VAT/bank data against vendor records with Verified/Warning/Suspicious status
- **Verify Action** - Manual re-verification button in Invoice Preview after editing fields
- New table: PaperTide Vendor Name Mapping (50104)
- New page: PaperTide Vendor Mappings (50106)
- New enum: PaperTide Inv. Verif. Status

### v1.0.0.24
- Multi-file drag & drop upload
- PDF support via Gotenberg conversion service
- AI GL Account Suggestion
- Batch processing with concurrency control
- Invoice image preview and document attachment

## Future Enhancements

- [ ] **Vendor Invoice Defaults** - Per-vendor setup for default line type (G/L Account or Item), default allocation account, and other invoice creation defaults
- [ ] **Purchase Order Linking** - Automatically link invoices to existing POs via extracted PO number and "Get Receipt Lines"
- [ ] **VIES VAT Validation** - Validate vendor VAT numbers against the EU VIES service at import, using vendor card Country Code + VAT No.
- [ ] **Azure File Storage Import** - Connect to Azure File Storage for automated invoice import
- [ ] Confidence scores per extracted field
- [ ] Highlight low-confidence fields for review
- [ ] Configurable field mapping for non-standard invoices
- [ ] Email integration (monitor inbox for invoice attachments)
- [ ] Azure Document AI as alternative provider
- [ ] Historical pattern learning for GL account suggestions
- [ ] Mobile app for camera capture
- [ ] Automatic approval for high-confidence extractions

## License

This is a custom Per-Tenant Extension (PTE) for your organization.

## Support

For issues or questions, contact your Business Central partner or development team.

---

**Version:** 1.0.2.0
**Compatible with:** Business Central 27.4+
**Runtime:** 14.0+
**Last Updated:** 2026-03-15
