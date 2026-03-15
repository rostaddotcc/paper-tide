# AI Invoice Extractor - Copilot Instructions

This document contains coding patterns, conventions, and architectural guidelines for working with this Business Central AL extension codebase.

## Project Overview

**Extension Name:** AI Invoice Extractor  
**Purpose:** AI-driven OCR for purchase invoices using OpenAI-compatible vision APIs
**Object ID Range:** 50100-50149  
**Runtime:** 14.0  
**Features:** `NoImplicitWith` enabled

---

## 1. Code Patterns and Conventions

### 1.1 Object Structure

#### Tables
```al
table 50100 "Table Name"
{
    Caption = 'Table Name';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }
        // Standard fields follow...
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Field1", "Field2")
        {
        }
    }

    trigger OnInsert()
    begin
        // Auto-populate system fields
        "Import DateTime" := CurrentDateTime();
        "Imported By" := UserId();
    end;
}
```

**Key Patterns:**
- Primary key is always `Entry No.` (Integer, AutoIncrement) for master tables
- System metadata fields use `DataClassification = SystemMetadata`
- Business data fields use `DataClassification = CustomerContent`
- Use `fieldgroups` for dropdown lookups
- Auto-populate audit fields (`Import DateTime`, `Imported By`) in `OnInsert` trigger

#### Codeunits
```al
codeunit 50100 "Codeunit Name"
{
    Access = Internal;  // Always mark as Internal unless external access needed

    var
        // Global labels at top
        ErrorMsgLbl: Label 'Error message with %1 placeholder';

    procedure PublicProcedure(Param: Type): ReturnType
    var
        // Local variables
        LocalVar: Type;
    begin
        // Implementation
    end;

    local procedure InternalHelper()
    begin
        // Private helper
    end;
}
```

**Key Patterns:**
- Always set `Access = Internal` by default
- Group global labels in a `var` section at the top
- Use PascalCase for procedure names
- Use `local` for helper procedures not exposed outside the codeunit
- Pass records as `var` when modifying them

#### Pages
```al
page 50100 "Page Name"
{
    Caption = 'Page Name';
    PageType = Card;  // or List, Card, etc.
    SourceTable = "Table Name";
    ApplicationArea = All;
    UsageCategory = Lists;  // or Administration, Tasks

    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                Caption = 'Group Caption';

                field("Field Name"; Rec."Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Descriptive tooltip';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;
                Caption = 'Action Caption';
                ToolTip = 'Action tooltip';
                Image = ActionImage;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    // Action logic
                end;
            }
        }
    }
}
```

**Key Patterns:**
- Always specify `ApplicationArea = All` on fields and actions
- Always provide `ToolTip` for fields and actions
- Use promoted actions for primary workflow steps
- Set `Editable = false` on list pages for read-only views

---

## 2. Naming Conventions

### 2.1 Object Naming
| Object Type | Pattern | Example |
|-------------|---------|---------|
| Table | Descriptive noun | `"Import Document Header"` |
| Table (Temporary) | "Temp" prefix | `"Temp Invoice Buffer"` |
| Codeunit | Descriptive noun | `"Invoice Extraction"` |
| Page | Descriptive noun | `"Invoice Preview"` |
| PageExtension | "Ext" suffix | `"Purch. Invoice List Ext"` |
| Enum | Descriptive status name | `"Import Document Status"` |

### 2.2 Variable Naming
| Type | Pattern | Example |
|------|---------|---------|
| Record | Singular noun | `ImportDocHeader`, `PurchHeader` |
| Codeunit | Same as object | `InvoiceExtraction`, `AIVisionAPI` |
| JsonObject | "Json" prefix + descriptive | `ExtractedData`, `ResponseJson` |
| JsonToken | "Token" suffix | `ContentToken`, `JsonToken` |
| Counter/Index | Descriptive + type | `LineIndex`, `ActiveCount` |
| Boolean | "Is" or "Has" prefix | `IsEditable`, `HasError` |
| Labels | Descriptive + "Lbl" suffix | `SetupNotConfiguredErr`, `ProcessingErr` |
| Text constants | Descriptive + suffix | `RequestBody`, `ResponseText` |

### 2.3 Field Naming
- Use proper case with spaces: `"Entry No."`, `"Vendor Name"`
- Standard BC field naming conventions
- Line tables use `"Line No."` for the line identifier
- Amount fields specify VAT status: `"Amount Incl. VAT"`, `"Amount Excl. VAT"`

---

## 3. Error Handling Patterns

### 3.1 Error Labels
Define error messages as global labels with descriptive names:

```al
var
    SetupNotConfiguredErr: Label 'AI Extraction Setup is not configured. Please configure API Base URL and API Key.';
    HttpRequestFailedErr: Label 'HTTP request failed with status code: %1\Error: %2';
    InvalidResponseErr: Label 'Invalid response from AI service: %1';
    RequestTimeoutErr: Label 'Request timed out after %1 ms. Please try again or increase timeout in setup.';
```

### 3.2 Validation Pattern
```al
local procedure ValidateSetup(Setup: Record "AI Extraction Setup")
begin
    if Setup."API Base URL" = '' then
        Error(SetupNotConfiguredErr);
    if Setup."API Key" = '' then
        Error(SetupNotConfiguredErr);
    if Setup."Model Name" = '' then
        Error(SetupNotConfiguredErr);
end;
```

### 3.3 Try-Catch Pattern for External Calls
```al
try
    // Risky operation (API call, file operation, etc.)
    if not AIVisionAPI.ExtractFromImage(Media, ExtractedData) then begin
        MarkAsError(ImportDocHeader, 'Failed to extract data from image');
        exit;
    end;
    
    // Success path
    ImportDocHeader.Status := ImportDocHeader.Status::Ready;
    ImportDocHeader.Modify();

catch
    // Error handling
    MarkAsError(ImportDocHeader, GetLastErrorText());
end;
```

### 3.4 Error Logging Pattern
```al
local procedure MarkAsError(var ImportDocHeader: Record "Import Document Header"; ErrorMsg: Text)
begin
    ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Error;
    ImportDocHeader."Error Message" := CopyStr(ErrorMsg, 1, 2048);  // Respect field length
    ImportDocHeader.Modify();
    
    // Continue processing other items
    ProcessNextIfAvailable();
end;
```

### 3.5 HTTP Error Handling
```al
// Check response status
if not HttpResponse.IsSuccessStatusCode() then begin
    HttpResponse.Content().ReadAs(ResponseText);
    Error(HttpRequestFailedErr, HttpResponse.HttpStatusCode(), ResponseText);
end;

// Check request success
if not HttpClient.Send(HttpRequest, HttpResponse) then
    Error(RequestTimeoutErr, Setup."Request Timeout (ms)");
```

---

## 4. API Integration Patterns

### 4.1 HTTP Client Setup
```al
procedure ExtractFromImage(Media: Media; var ExtractedData: JsonObject): Boolean
var
    Setup: Record "AI Extraction Setup";
    HttpClient: HttpClient;
    HttpRequest: HttpRequestMessage;
    HttpContent: HttpContent;
    HttpResponse: HttpResponseMessage;
    Headers: HttpHeaders;
    ContentHeaders: HttpHeaders;
begin
    Setup.GetOrCreateSetup();
    ValidateSetup(Setup);

    // Configure HTTP client
    HttpClient.SetBaseAddress(Setup."API Base URL");
    HttpClient.Timeout(Setup."Request Timeout (ms)");

    // Create request content
    HttpContent.WriteFrom(RequestBody);
    HttpContent.GetHeaders(ContentHeaders);
    ContentHeaders.Remove('Content-Type');
    ContentHeaders.Add('Content-Type', 'application/json');

    // Create request
    HttpRequest.Method := 'POST';
    HttpRequest.SetRequestUri('/chat/completions');
    HttpRequest.Content(HttpContent);
    HttpRequest.GetHeaders(Headers);
    Headers.Add('Authorization', SecretText.StrSubstNo('Bearer %1', Setup."API Key"));

    // Send and handle response
    if not HttpClient.Send(HttpRequest, HttpResponse) then
        Error(RequestTimeoutErr, Setup."Request Timeout (ms)");

    if not HttpResponse.IsSuccessStatusCode() then begin
        HttpResponse.Content().ReadAs(ResponseText);
        Error(HttpRequestFailedErr, HttpResponse.HttpStatusCode(), ResponseText);
    end;

    HttpResponse.Content().ReadAs(ResponseText);
    exit(ParseAIResponse(ResponseText, ExtractedData));
end;
```

### 4.2 JSON Building Pattern
```al
local procedure BuildRequestJson(Setup: Record "AI Extraction Setup"; Base64Image: Text) RequestJson: Text
var
    JsonObj: JsonObject;
    MessagesArr: JsonArray;
    MessageObj: JsonObject;
begin
    // Build nested JSON structure
    Clear(MessageObj);
    MessageObj.Add('role', 'system');
    MessageObj.Add('content', SystemPrompt);
    MessagesArr.Add(MessageObj);

    // Build main object
    JsonObj.Add('model', Setup."Model Name");
    JsonObj.Add('messages', MessagesArr);
    JsonObj.Add('max_tokens', Setup."Max Tokens");
    JsonObj.Add('temperature', Setup.Temperature);

    JsonObj.WriteTo(RequestJson);
end;
```

### 4.3 JSON Parsing Pattern
```al
local procedure GetJsonTextValue(JsonObj: JsonObject; FieldName: Text; MaxLength: Integer): Text
var
    JsonToken: JsonToken;
    ValueText: Text;
begin
    if not JsonObj.Get(FieldName, JsonToken) then
        exit('');

    if JsonToken.AsValue().IsNull() then
        exit('');

    ValueText := JsonToken.AsValue().AsText();
    if StrLen(ValueText) > MaxLength then
        ValueText := CopyStr(ValueText, 1, MaxLength);

    exit(ValueText);
end;

local procedure GetJsonDecimalValue(JsonObj: JsonObject; FieldName: Text): Decimal
var
    JsonToken: JsonToken;
begin
    if not JsonObj.Get(FieldName, JsonToken) then
        exit(0);

    if JsonToken.AsValue().IsNull() then
        exit(0);

    if JsonToken.AsValue().IsNumber() then
        exit(JsonToken.AsValue().AsDecimal());

    exit(0);
end;
```

### 4.4 Media/Base64 Conversion
```al
local procedure ConvertMediaToBase64(Media: Media) Base64String: Text
var
    Base64Convert: Codeunit "Base64 Convert";
    TempBlob: Codeunit "Temp Blob";
    InStream: InStream;
    OutStream: OutStream;
    MediaId: Guid;
begin
    if not Media.HasValue() then
        exit('');

    MediaId := Media.MediaId();
    if IsNullGuid(MediaId) then
        exit('');

    // Export media to stream
    TempBlob.CreateOutStream(OutStream);
    Media.ExportStream(OutStream);
    TempBlob.CreateInStream(InStream);

    // Convert to base64
    Base64String := Base64Convert.ToBase64(InStream);
end;
```

---

## 5. Key Architectural Patterns

### 5.1 Temporary Table Pattern
Used for preview/editing before committing to permanent records:

```al
table 50101 "Temp Invoice Buffer"
{
    Caption = 'Temp Invoice Buffer';
    TableType = Temporary;  // Critical: data is session-only
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        field(2; "Vendor No."; Code[20])
        // ... header fields
        field(20; "Line No."; Integer)
        field(21; "Line Description"; Text[100])
        // ... line fields
    }

    procedure SetHeaderValues(...)
    procedure AddLine(...)
}
```

**Usage:**
- Header record uses `Line No. = 0`
- Line records use `Line No. > 0` (10000, 20000, etc.)
- Single table holds both header and lines for simplicity

### 5.2 Batch Processing Pattern
Concurrency-controlled document processing:

```al
codeunit 50102 "Batch Processing Mgt"
{
    var
        MaxConcurrency: Integer;

    procedure StartProcessingWithConcurrency()
    var
        ImportDocHeader: Record "Import Document Header";
        ActiveCount: Integer;
        SlotsAvailable: Integer;
    begin
        MaxConcurrency := 3;

        // Count currently processing
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Processing);
        ActiveCount := ImportDocHeader.Count();

        if ActiveCount >= MaxConcurrency then
            exit;

        SlotsAvailable := MaxConcurrency - ActiveCount;

        // Start processing for available slots
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Pending);
        for i := 1 to SlotsAvailable do begin
            if ImportDocHeader.FindFirst() then
                StartProcessingDocument(ImportDocHeader)
            else
                break;
        end;
    end;
}
```

### 5.3 Dual Status Pattern
Documents track both workflow status and processing status:

```al
// Workflow status
enum 50100 "Import Document Status"
{
    value(0; Pending)       { Caption = 'Pending'; }
    value(1; Ready)         { Caption = 'Ready for Review'; }
    value(2; Created)       { Caption = 'Invoice Created'; }
    value(3; Discarded)     { Caption = 'Discarded'; }
}

// Processing status
enum 50101 "Import Processing Status"
{
    value(0; Pending)       { Caption = 'Pending'; }
    value(1; Processing)    { Caption = 'Processing'; }
    value(2; Completed)     { Caption = 'Completed'; }
    value(3; Error)         { Caption = 'Error'; }
}
```

### 5.4 Setup Table Pattern
Single-record setup table with helper methods:

```al
table 50100 "AI Extraction Setup"
{
    fields
    {
        field(1; "Primary Key"; Code[10])
        field(2; "API Base URL"; Text[250])
        field(3; "API Key"; SecretText)  // Use SecretText for sensitive data
        // ...
    }

    procedure GetOrCreateSetup()
    begin
        if not Get() then begin
            Init();
            Insert(true);
        end;
    end;

    procedure GetOrCreateSetup(): Record "AI Extraction Setup"
    begin
        if not Get() then begin
            Init();
            // Set defaults
            "Model Name" := 'gpt-4o';
            "Max Tokens" := 2048;
            Temperature := 0.1;
            Insert();
        end;
        exit(Rec);
    end;
}
```

### 5.5 Blob Text Storage Pattern
For storing large text (like prompts) in tables:

```al
field(7; "System Prompt"; Blob)
{
    Caption = 'System Prompt';
    DataClassification = CustomerContent;
}

procedure GetSystemPrompt(): Text
var
    TypeHelper: Codeunit "Type Helper";
    InStream: InStream;
    PromptText: Text;
begin
    CalcFields("System Prompt");
    if "System Prompt".HasValue() then begin
        "System Prompt".CreateInStream(InStream, TextEncoding::UTF8);
        TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator(), PromptText);
        exit(PromptText);
    end;
    exit(GetDefaultSystemPrompt());
end;

procedure SetSystemPrompt(PromptText: Text)
var
    OutStream: OutStream;
begin
    Clear("System Prompt");
    if PromptText <> '' then begin
        "System Prompt".CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(PromptText);
    end;
end;
```

---

## 6. Data Flow Patterns

### 6.1 Invoice Processing Flow
```
Image Upload → Import Document Header (Pending)
                    ↓
         Batch Processing Mgt (concurrency control)
                    ↓
         Batch API Worker → AI Vision API
                    ↓
         ParseAndSaveToImportDoc → Import Document Header (Ready)
                    ↓
         User Review → CreateInvoiceFromImportDoc
                    ↓
         Purchase Header (Invoice Created)
```

### 6.2 Single Invoice Flow (Direct)
```
Image Upload → Temp Invoice Buffer (temporary preview)
                    ↓
         AI Vision API → ParseAndFillBuffer
                    ↓
         User Review → CreatePurchaseInvoice
                    ↓
         Purchase Header
```

---

## 7. Best Practices Observed

1. **Always use `Access = Internal`** on codeunits unless external access is explicitly required
2. **Use `SecretText`** for API keys and sensitive configuration
3. **Respect field lengths** when copying error messages: `CopyStr(ErrorMsg, 1, 2048)`
4. **Use `Commit()`** before long-running operations to persist status changes
5. **Validate with `Confirm()`** before destructive operations
6. **Use `StyleExpr`** for conditional formatting in lists
7. **Provide `ToolTip`** for all fields and actions
8. **Use `ObsoleteState = Pending`** for fields reserved for future use
9. **Default G/L Account** from setup for invoice lines when account cannot be determined
10. **Always create at least one line** in purchase invoices (even if no lines extracted)

---

## 8. File Organization

```
API/
  - InvoiceExtraction.Codeunit.al    # Core extraction logic
  - AIVisionAPI.Codeunit.al           # API communication

BatchProcessing/
  - BatchAPIWorker.Codeunit.al       # Individual document processing
  - BatchProcessingMgt.Codeunit.al   # Concurrency management
  - BatchUpload.Page.al              # Multi-file upload UI
  - ImportDocumentHeader.Table.al    # Persistent import queue
  - ImportDocumentLine.Table.al      # Line details for queue
  - ImportDocumentList.Page.al       # Queue management UI

InvoiceProcessing/
  - InvoicePreview.Page.al           # Single invoice preview
  - InvoicePreviewSubform.Page.al    # Lines subpage
  - InvoiceImageFactBox.Page.al      # Image preview
  - TempInvoiceBuffer.Table.al       # Temporary preview data

Pages/
  - PurchaseInvoiceListExt.PageExt.al # Entry points from Purchase Invoices

Setup/
  - AIExtractionSetup.Table.al       # Configuration table
  - AIExtractionSetup.Page.al        # Configuration UI
```
