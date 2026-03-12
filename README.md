# AI Invoice Extractor for Business Central

A Per-Tenant Extension (PTE) for Business Central that uses AI (Qwen-VL) to extract invoice data from images, with a preview and approval workflow.

## Features

- 🤖 **AI-Powered OCR** - Extract invoice data using Qwen-VL vision model
- 📦 **Batch Import** - Upload and process multiple invoice images simultaneously
- ⚡ **Concurrency Control** - Process up to 3 images at once with automatic queue management
- 📋 **Import Queue** - View and manage all imported documents with status tracking
- 👁️ **Preview & Edit** - Review extracted data with original image in FactBox before creating
- ⚙️ **Configurable** - Set up your own API endpoint, model, system prompt, and default G/L account
- 🔒 **Secure** - API keys stored with masked display
- 📊 **Status Tracking** - Track documents from Pending → Processing → Ready → Created
- 🔍 **Duplicate Detection** - Prevent duplicate vendor invoice numbers
- 🏢 **Vendor Matching** - Automatic vendor lookup by number or name

## Requirements

- Business Central 2024 Wave 2 (v27.4) or later
- Qwen-VL API access (Alibaba Cloud DashScope or compatible)
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

1. Search for **"AI Extraction Setup"** in Business Central
2. Fill in the following fields:

| Field | Example Value | Description |
|-------|---------------|-------------|
| API Base URL | `https://dashscope.aliyuncs.com/compatible-mode/v1` | Qwen-VL API endpoint |
| API Key | `sk-xxxxxxxx` | Your API key from Alibaba Cloud |
| Model Name | `qwen-vl-max` | Model identifier |
| Max Tokens | `2048` | Response length limit |
| Temperature | `0.1` | AI creativity (0.0 = strict) |
| Request Timeout | `60000` | API request timeout in milliseconds |
| Default G/L Account | `6110` | Default G/L account for invoice lines |
| System Prompt | *(see below)* | Instructions for data extraction |

### Default System Prompt

The extension includes a default system prompt that instructs the AI to return JSON in this format:

```json
{
  "VendorNo": "VEND001",
  "VendorName": "Acme Supplies",
  "InvoiceNo": "INV-2024-001",
  "InvoiceDate": "2024-03-15",
  "DueDate": "2024-04-15",
  "AmountInclVAT": 12500.00,
  "AmountExclVAT": 10000.00,
  "VATAmount": 2500.00,
  "CurrencyCode": "SEK",
  "Lines": [
    {
      "Description": "Consulting services",
      "Quantity": 10,
      "UnitPrice": 1000.00,
      "Amount": 10000.00
    }
  ]
}
```

You can customize the system prompt in the setup page to match your specific invoice formats.

## Usage

### Workflow Overview

```
Upload → Process (AI) → Review → Create Invoice
```

### 1. Batch Upload

1. Navigate to **Purchase Invoices** page
2. Click **"Batch Upload Invoices"** in the ribbon
3. Click **"Select Files"** button
4. Select one or more JPG/PNG files (you can upload multiple files in sequence)
5. Files are automatically queued and processed (max 3 concurrent)
6. The **Processing Queue** shows counts: Pending, Processing, Ready for Review, Errors, Created

### 2. Monitor Processing

- **Pending**: Waiting for processing slot
- **Processing**: AI extraction in progress
- **Ready for Review**: Extraction complete, ready for your review
- **Errors**: Processing failed (hover to see error message)
- **Created**: Invoice already created from this document

### 3. Review & Edit

1. Click **"View Import Queue"** to see all documents
2. Find a document with status **"Ready"**
3. Click **"Review & Edit"** to open **Invoice Preview**
4. Review extracted data:
   - Header fields (Vendor, Invoice No, Dates, Amounts)
   - Line items in the subform
   - Original image in the FactBox on the right
5. Click **"Edit Values"** to enable editing if corrections are needed
6. Make corrections and fields will auto-save

### 4. Create Invoice

1. After review, click **"Accept & Create Invoice"**
2. System validates:
   - Vendor No. is specified
   - Invoice No. is specified
   - No duplicate vendor invoice number exists
3. Purchase Invoice is created with:
   - Header data from extracted information
   - Lines from extracted line items (or one line with total if no lines)
   - Default G/L Account from setup
4. Document status changes to **"Created"**
5. Created invoice opens automatically

### 5. View Created Invoices

- Documents with status **"Created"** cannot be edited or re-processed
- Click **"View Created Invoice"** to open the purchase invoice
- The **"Created Invoice No."** field shows the linked invoice number

### Supported File Formats

| Format | Status | Notes |
|--------|--------|-------|
| JPG/JPEG | ✅ Supported | Recommended |
| PNG | ✅ Supported | Recommended |
| PDF | ❌ Not supported (v1.0) | Convert to image first |

## Architecture

### Batch Import Flow

```
User selects multiple images
        ↓
[Batch Upload Page] → Queue files
        ↓
[Batch Processing Mgt] → Concurrency control (max 3)
        ↓
[Batch API Worker] → Process each image
        ↓
[Qwen VL API Codeunit] → HTTP POST with base64 image
        ↓
Qwen-VL AI processes image
        ↓
[Invoice Extraction Codeunit] → Parse JSON response
        ↓
Save to Import Document Header + Lines
        ↓
[Import Document List] → Display with status
        ↓
User opens Invoice Preview → Review & edit
        ↓
Create Purchase Header + Lines
        ↓
Mark Import Document as "Created"
```

### Status Flow

```
Pending → Processing → Ready → Created
   ↓          ↓         ↓
   └──────────┴─────────┘→ Error (retryable)
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

| Object | Type | Purpose |
|--------|------|---------|
| AI Extraction Setup | Table | Configuration storage (singleton) |
| Temp Invoice Buffer | Table | Temporary data for preview |
| Qwen VL API | Codeunit | HTTP client for AI service |
| Invoice Extraction | Codeunit | Parser and invoice creator |
| Invoice Preview | Page | Review interface with image FactBox |

## Troubleshooting

### "Setup is not configured"
- Go to **AI Extraction Setup** page (search for it)
- Fill in **API Base URL** and **API Key**
- Fill in **Model Name** (e.g., `qwen-vl-max`)
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
- In Extension Management, click Configure → Allow HttpClient Requests

### Cannot see AI Extraction Setup page
- Ensure you have the **"AI Invoice Extractor"** permission set assigned
- Go to Users → select your user → Permission Sets → add "AI Invoice Extractor"

## Future Enhancements

### Version 2.0
- [ ] **Azure File Storage Import** - Connect to Azure File Storage for automated invoice import
- [ ] **PDF Support** - Convert PDF to base64 and send directly to Qwen-VL for processing
- [ ] Confidence scores per extracted field
- [ ] Highlight low-confidence fields for review
- [ ] Configurable field mapping for non-standard invoices
- [ ] Multi-page invoice support
- [ ] Email integration (monitor inbox for invoice attachments)

### Version 3.0
- [ ] Azure Document AI as alternative provider
- [ ] Machine learning for vendor auto-matching
- [ ] Historical pattern learning for GL account suggestions
- [ ] Mobile app for camera capture
- [ ] Automatic approval for high-confidence extractions

## License

This is a custom Per-Tenant Extension (PTE) for your organization.

## Support

For issues or questions, contact your Business Central partner or development team.

---

**Version:** 1.0.0.15  
**Compatible with:** Business Central 27.4+  
**Runtime:** 14.0+  
**Last Updated:** 2024-03-12
