codeunit 50101 "PaperTide Invoice Extraction"
{
    Access = Internal;

    var
        VendorNoRequiredErr: Label 'Vendor No. must be specified before creating invoice.';
        InvoiceNoRequiredErr: Label 'Invoice No. must be specified before creating invoice.';
        ImportDocNotFoundErr: Label 'Import document not found.';
        InvoiceAlreadyCreatedErr: Label 'Invoice already created for this document.';

    procedure ParseAndFillBuffer(
        ExtractedData: JsonObject;
        MediaId: Guid;
        var TempBuffer: Record "PaperTide Temp Invoice Buffer")
    var
        JsonToken: JsonToken;
        LinesArr: JsonArray;
        LineObj: JsonObject;
        LineToken: JsonToken;
        LineIndex: Integer;
        VendorNo: Code[20];
        VendorName: Text[100];
        InvoiceNo: Code[35];
        InvoiceDate: Date;
        DueDate: Date;
        AmountInclVAT: Decimal;
        AmountExclVAT: Decimal;
        VATAmount: Decimal;
        CurrencyCode: Code[10];
    begin
        // Clear existing buffer
        TempBuffer.DeleteAll();
        TempBuffer."Entry No." := 1;

        // Parse header fields
        VendorNo := GetJsonTextValue(ExtractedData, 'VendorNo', 20);
        VendorName := GetJsonTextValue(ExtractedData, 'VendorName', 100);
        InvoiceNo := GetJsonTextValue(ExtractedData, 'InvoiceNo', 35);
        InvoiceDate := GetJsonDateValue(ExtractedData, 'InvoiceDate');
        DueDate := GetJsonDateValue(ExtractedData, 'DueDate');
        AmountInclVAT := GetJsonDecimalValue(ExtractedData, 'AmountInclVAT');
        AmountExclVAT := GetJsonDecimalValue(ExtractedData, 'AmountExclVAT');
        VATAmount := GetJsonDecimalValue(ExtractedData, 'VATAmount');
        CurrencyCode := GetJsonTextValue(ExtractedData, 'CurrencyCode', 10);

        // Try to find vendor by number or name
        VendorNo := LookupVendorNo(VendorNo, VendorName);

        // Set header values in buffer (Line No. = 0 for header)
        TempBuffer."Line No." := 0;
        TempBuffer.SetHeaderValues(
            VendorNo,
            VendorName,
            InvoiceNo,
            InvoiceDate,
            DueDate,
            AmountInclVAT,
            AmountExclVAT,
            VATAmount,
            CurrencyCode,
            MediaId
        );
        TempBuffer.Insert();

        // Parse lines
        if ExtractedData.Get('Lines', JsonToken) then begin
            LinesArr := JsonToken.AsArray();
            for LineIndex := 0 to LinesArr.Count() - 1 do begin
                LinesArr.Get(LineIndex, LineToken);
                LineObj := LineToken.AsObject();

                ParseAndInsertLine(TempBuffer, LineIndex + 1, LineObj);
            end;
        end;

        // Re-read header record
        TempBuffer.Get(1, 0);
    end;

    local procedure LookupVendorNo(VendorNo: Code[20]; VendorName: Text[100]): Code[20]
    begin
        exit(LookupVendorNoExtended(VendorNo, VendorName, '', ''));
    end;

    local procedure LookupVendorNoExtended(VendorNo: Code[20]; VendorName: Text[100]; VATNo: Text[20]; BankAccount: Text[50]): Code[20]
    var
        Vendor: Record Vendor;
        VendorBankAccount: Record "Vendor Bank Account";
        VendorNameMapping: Record "PaperTide Vendor Name Mapping";
    begin
        // Step 0: Check vendor name mapping table first
        if VendorName <> '' then
            if VendorNameMapping.Get(VendorName) then
                if Vendor.Get(VendorNameMapping."Vendor No.") then begin
                    VendorNameMapping."Usage Count" += 1;
                    VendorNameMapping.Modify();
                    exit(VendorNameMapping."Vendor No.");
                end;

        // Step 1: Check if AI-extracted vendor number is valid
        if VendorNo <> '' then
            if not Vendor.Get(VendorNo) then
                VendorNo := '';

        if VendorNo <> '' then
            exit(VendorNo);

        // Step 2: Match by VAT Registration No. (highly reliable, unique)
        if VATNo <> '' then begin
            Vendor.Reset();
            Vendor.SetRange("VAT Registration No.", VATNo);
            if Vendor.FindFirst() then
                exit(Vendor."No.");
        end;

        // Step 3: Match by bank account / IBAN
        if BankAccount <> '' then begin
            VendorBankAccount.Reset();
            VendorBankAccount.SetRange(IBAN, BankAccount);
            if VendorBankAccount.FindFirst() then
                exit(VendorBankAccount."Vendor No.");
            VendorBankAccount.Reset();
            VendorBankAccount.SetRange("Bank Account No.", BankAccount);
            if VendorBankAccount.FindFirst() then
                exit(VendorBankAccount."Vendor No.");
        end;

        // Step 4-5: Try matching by name
        if VendorName <> '' then begin
            Vendor.Reset();
            Vendor.SetRange(Name, VendorName);
            if Vendor.FindFirst() then
                exit(Vendor."No.");
            Vendor.SetFilter(Name, '@*' + VendorName + '*');
            if Vendor.FindFirst() then
                exit(Vendor."No.");
        end;

        exit('');
    end;

    local procedure ParseAndInsertLine(
        var TempBuffer: Record "PaperTide Temp Invoice Buffer";
        LineNo: Integer;
        LineObj: JsonObject)
    var
        Description: Text[100];
        Quantity: Decimal;
        UnitPrice: Decimal;
        LineAmount: Decimal;
    begin
        Description := GetJsonTextValue(LineObj, 'Description', 100);
        Quantity := GetJsonDecimalValue(LineObj, 'Quantity');
        UnitPrice := GetJsonDecimalValue(LineObj, 'UnitPrice');
        LineAmount := GetJsonDecimalValue(LineObj, 'Amount');

        // Calculate missing values
        if (LineAmount = 0) and (Quantity > 0) and (UnitPrice > 0) then
            LineAmount := Round(Quantity * UnitPrice, 0.01);

        TempBuffer.AddLine(LineNo, Description, Quantity, UnitPrice, LineAmount);
    end;

    procedure CreatePurchaseInvoice(TempBuffer: Record "PaperTide Temp Invoice Buffer"): Code[20]
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        TempLine: Record "PaperTide Temp Invoice Buffer";
        AISetup: Record "PaperTide AI Setup";
        LineNo: Integer;
        DefaultGLAccount: Code[20];
    begin
        // Get default G/L account from setup
        if AISetup.Get() then
            DefaultGLAccount := AISetup."Default G/L Account";
        // Get header record
        TempBuffer.Get(1, 0);

        // Validate required fields
        if TempBuffer."Vendor No." = '' then
            Error(VendorNoRequiredErr);
        if TempBuffer."Invoice No." = '' then
            Error(InvoiceNoRequiredErr);

        // Create purchase invoice header
        PurchHeader.Init();
        PurchHeader."Document Type" := PurchHeader."Document Type"::Invoice;
        PurchHeader.Validate("Buy-from Vendor No.", TempBuffer."Vendor No.");
        PurchHeader.Validate("Vendor Invoice No.", TempBuffer."Invoice No.");
        if TempBuffer."Invoice Date" <> 0D then
            PurchHeader.Validate("Document Date", TempBuffer."Invoice Date");
        if TempBuffer."Due Date" <> 0D then
            PurchHeader.Validate("Due Date", TempBuffer."Due Date");
        if TempBuffer."Currency Code" <> '' then
            PurchHeader.Validate("Currency Code", TempBuffer."Currency Code");
        PurchHeader.Insert(true);

        // Create lines
        TempLine.Copy(TempBuffer);
        TempLine.SetRange("Entry No.", 1);
        TempLine.SetFilter("Line No.", '>0');

        if TempLine.FindSet() then begin
            LineNo := 10000;
            repeat
                PurchLine.Init();
                PurchLine."Document Type" := PurchHeader."Document Type";
                PurchLine."Document No." := PurchHeader."No.";
                PurchLine."Line No." := LineNo;
                PurchLine.Validate(Type, PurchLine.Type::"G/L Account");
                // Use default G/L account from setup if configured
                if DefaultGLAccount <> '' then
                    PurchLine.Validate("No.", DefaultGLAccount);
                PurchLine.Validate(Description, TempLine."Line Description");
                if TempLine."Line Quantity" <> 0 then
                    PurchLine.Validate(Quantity, TempLine."Line Quantity");
                if TempLine."Line Unit Price" <> 0 then
                    PurchLine.Validate("Direct Unit Cost", TempLine."Line Unit Price");
                if TempLine."Line Amount" <> 0 then
                    PurchLine.Validate("Line Amount", TempLine."Line Amount");
                PurchLine.Insert(true);

                LineNo += 10000;
            until TempLine.Next() = 0;
        end else
            InsertFallbackPurchLine(PurchHeader, DefaultGLAccount, TempBuffer."Amount Incl. VAT");

        exit(PurchHeader."No.");
    end;

    procedure ParseAndSaveToImportDoc(
        ExtractedData: JsonObject;
        var ImportDocHeader: Record "PaperTide Import Doc. Header")
    var
        ImportDocLine: Record "PaperTide Import Doc. Line";
        GLAccount: Record "G/L Account";
        AISetup: Record "PaperTide AI Setup";
        JsonToken: JsonToken;
        LinesArr: JsonArray;
        LineObj: JsonObject;
        LineToken: JsonToken;
        LineIndex: Integer;
        VendorNo: Code[20];
        VendorName: Text[100];
        InvoiceNo: Code[35];
        InvoiceDate: Date;
        DueDate: Date;
        AmountInclVAT: Decimal;
        AmountExclVAT: Decimal;
        VATAmount: Decimal;
        CurrencyCode: Code[10];
        PONumber: Code[35];
        VATNo: Text[20];
        BankAccount: Text[50];
        EntryNo: Integer;
        DefaultGLAccount: Code[20];
    begin
        EntryNo := ImportDocHeader."Entry No.";

        // Get default G/L account from setup
        if AISetup.Get() then
            DefaultGLAccount := AISetup."Default G/L Account";

        // Clear existing lines
        ImportDocLine.SetRange("Entry No.", EntryNo);
        ImportDocLine.DeleteAll();

        // Parse header fields
        VendorNo := GetJsonTextValue(ExtractedData, 'VendorNo', 20);
        VendorName := GetJsonTextValue(ExtractedData, 'VendorName', 100);
        InvoiceNo := GetJsonTextValue(ExtractedData, 'InvoiceNo', 35);
        InvoiceDate := GetJsonDateValue(ExtractedData, 'InvoiceDate');
        DueDate := GetJsonDateValue(ExtractedData, 'DueDate');
        AmountInclVAT := GetJsonDecimalValue(ExtractedData, 'AmountInclVAT');
        AmountExclVAT := GetJsonDecimalValue(ExtractedData, 'AmountExclVAT');
        VATAmount := GetJsonDecimalValue(ExtractedData, 'VATAmount');
        CurrencyCode := GetJsonTextValue(ExtractedData, 'CurrencyCode', 10);
        PONumber := GetJsonTextValue(ExtractedData, 'PONumber', 35);
        VATNo := GetJsonTextValue(ExtractedData, 'VendorVATNo', 20);
        BankAccount := GetJsonTextValue(ExtractedData, 'VendorBankAccount', 50);

        // Try to find vendor by number, VAT no., bank account, or name
        VendorNo := LookupVendorNoExtended(VendorNo, VendorName, VATNo, BankAccount);

        // Update header with extracted values
        ImportDocHeader."Vendor No." := VendorNo;
        ImportDocHeader."Vendor Name" := VendorName;
        ImportDocHeader."Invoice No." := InvoiceNo;
        ImportDocHeader."Invoice Date" := InvoiceDate;
        ImportDocHeader."Due Date" := DueDate;
        ImportDocHeader."Amount Incl. VAT" := AmountInclVAT;
        ImportDocHeader."Amount Excl. VAT" := AmountExclVAT;
        ImportDocHeader."VAT Amount" := VATAmount;
        ImportDocHeader."Currency Code" := CurrencyCode;
        ImportDocHeader."PO Number" := PONumber;
        ImportDocHeader."Vendor VAT No." := VATNo;
        ImportDocHeader."Vendor Bank Account" := BankAccount;

        // Cross-validate extracted data against known vendor data
        VerifyVendorData(ImportDocHeader);
        ImportDocHeader.Modify();

        // Parse and save lines
        if ExtractedData.Get('Lines', JsonToken) then begin
            LinesArr := JsonToken.AsArray();
            for LineIndex := 0 to LinesArr.Count() - 1 do begin
                LinesArr.Get(LineIndex, LineToken);
                LineObj := LineToken.AsObject();

                ImportDocLine.Init();
                ImportDocLine."Entry No." := EntryNo;
                ImportDocLine."Line No." := (LineIndex + 1) * 10000;
                ImportDocLine.Description := GetJsonTextValue(LineObj, 'Description', 100);
                ImportDocLine.Quantity := GetJsonDecimalValue(LineObj, 'Quantity');
                ImportDocLine."Unit Price" := GetJsonDecimalValue(LineObj, 'UnitPrice');
                ImportDocLine."Line Amount" := GetJsonDecimalValue(LineObj, 'Amount');
                // Default to G/L Account - user can change in preview if needed
                ImportDocLine.Type := ImportDocLine.Type::"G/L Account";
                // Use AI-suggested G/L Account if available and valid, otherwise use default from setup
                ImportDocLine."No." := GetJsonTextValue(LineObj, 'GLAccountNo', 20);
                if (ImportDocLine."No." <> '') and not GLAccount.Get(ImportDocLine."No.") then
                    ImportDocLine."No." := '';  // Discard invalid account suggested by AI

                if ImportDocLine."No." = '' then
                    ImportDocLine."No." := DefaultGLAccount;

                // Calculate missing values
                if (ImportDocLine."Line Amount" = 0) and (ImportDocLine.Quantity > 0) and (ImportDocLine."Unit Price" > 0) then
                    ImportDocLine."Line Amount" := Round(ImportDocLine.Quantity * ImportDocLine."Unit Price", 0.01);

                ImportDocLine.Insert();
            end;
        end;
    end;

    procedure CreateInvoiceFromImportDoc(EntryNo: Integer): Code[20]
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        ImportDocLine: Record "PaperTide Import Doc. Line";
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        AISetup: Record "PaperTide AI Setup";
        LineNo: Integer;
        DefaultGLAccount: Code[20];
    begin
        if not ImportDocHeader.Get(EntryNo) then
            Error(ImportDocNotFoundErr);

        if ImportDocHeader.Status = ImportDocHeader.Status::Created then
            Error(InvoiceAlreadyCreatedErr);

        // Get default G/L account from setup
        if AISetup.Get() then
            DefaultGLAccount := AISetup."Default G/L Account";

        // Validate required fields
        if ImportDocHeader."Vendor No." = '' then
            Error(VendorNoRequiredErr);
        if ImportDocHeader."Invoice No." = '' then
            Error(InvoiceNoRequiredErr);

        // Create purchase invoice header
        PurchHeader.Init();
        PurchHeader."Document Type" := PurchHeader."Document Type"::Invoice;
        PurchHeader.Validate("Buy-from Vendor No.", ImportDocHeader."Vendor No.");
        PurchHeader.Validate("Vendor Invoice No.", ImportDocHeader."Invoice No.");
        if ImportDocHeader."Invoice Date" <> 0D then begin
            PurchHeader.Validate("Document Date", ImportDocHeader."Invoice Date");
            PurchHeader.Validate("Posting Date", ImportDocHeader."Invoice Date");
        end;
        if ImportDocHeader."Due Date" <> 0D then
            PurchHeader.Validate("Due Date", ImportDocHeader."Due Date");
        if ImportDocHeader."Payment Terms Code" <> '' then
            PurchHeader.Validate("Payment Terms Code", ImportDocHeader."Payment Terms Code");
        if ImportDocHeader."Payment Method Code" <> '' then
            PurchHeader.Validate("Payment Method Code", ImportDocHeader."Payment Method Code");
        if ImportDocHeader."PO Number" <> '' then
            PurchHeader."Vendor Order No." := ImportDocHeader."PO Number";
        PurchHeader.Insert(true);

        // Create lines
        ImportDocLine.SetRange("Entry No.", EntryNo);

        if ImportDocLine.FindSet() then begin
            LineNo := 10000;
            repeat
                PurchLine.Init();
                PurchLine."Document Type" := PurchHeader."Document Type";
                PurchLine."Document No." := PurchHeader."No.";
                PurchLine."Line No." := LineNo;

                // Always use Type from import line (defaults to G/L Account)
                PurchLine.Validate(Type, ImportDocLine.Type);

                // Use No. from import line if specified, otherwise use Default G/L Account
                if ImportDocLine."No." <> '' then
                    PurchLine.Validate("No.", ImportDocLine."No.")
                else if DefaultGLAccount <> '' then
                    PurchLine.Validate("No.", DefaultGLAccount);

                PurchLine.Validate(Description, ImportDocLine.Description);
                if ImportDocLine.Quantity <> 0 then
                    PurchLine.Validate(Quantity, ImportDocLine.Quantity);
                if ImportDocLine."Unit Price" <> 0 then
                    PurchLine.Validate("Direct Unit Cost", ImportDocLine."Unit Price");
                if ImportDocLine."Line Amount" <> 0 then
                    PurchLine.Validate("Line Amount", ImportDocLine."Line Amount");
                PurchLine.Insert(true);

                LineNo += 10000;
            until ImportDocLine.Next() = 0;
        end else
            InsertFallbackPurchLine(PurchHeader, DefaultGLAccount, ImportDocHeader."Amount Incl. VAT");

        // Attach invoice image to purchase invoice
        AttachInvoiceImageToPurchaseInvoice(ImportDocHeader, PurchHeader."No.");

        // Update import document as created
        ImportDocHeader.Status := ImportDocHeader.Status::Created;
        ImportDocHeader."Created Invoice No." := PurchHeader."No.";
        ImportDocHeader.Modify();

        exit(PurchHeader."No.");
    end;

    local procedure InsertFallbackPurchLine(var PurchHeader: Record "Purchase Header"; DefaultGLAccount: Code[20]; LineAmount: Decimal)
    var
        PurchLine: Record "Purchase Line";
    begin
        PurchLine.Init();
        PurchLine."Document Type" := PurchHeader."Document Type";
        PurchLine."Document No." := PurchHeader."No.";
        PurchLine."Line No." := 10000;
        PurchLine.Validate(Type, PurchLine.Type::"G/L Account");
        if DefaultGLAccount <> '' then
            PurchLine.Validate("No.", DefaultGLAccount);
        PurchLine.Validate(Description, 'Invoice amount - please review and assign account');
        if LineAmount <> 0 then
            PurchLine.Validate("Line Amount", LineAmount);
        PurchLine.Insert(true);
    end;

    local procedure AttachInvoiceImageToPurchaseInvoice(ImportDocHeader: Record "PaperTide Import Doc. Header"; PurchaseInvoiceNo: Code[20])
    var
        DocumentAttachment: Record "Document Attachment";
        InStream: InStream;
        FileName: Text;
        FileExtension: Text;
    begin
        // Prefer original PDF if available (contains all pages)
        ImportDocHeader.CalcFields("Original PDF Blob", "Image Blob");

        if ImportDocHeader."Is PDF" and ImportDocHeader."Original PDF Blob".HasValue() then begin
            FileName := ImportDocHeader."File Name";
            if FileName = '' then
                FileName := 'Invoice_' + Format(ImportDocHeader."Entry No.") + '.pdf';
            FileExtension := 'pdf';
            ImportDocHeader."Original PDF Blob".CreateInStream(InStream);
        end else begin
            if not ImportDocHeader."Image Blob".HasValue() then
                exit;
            FileName := ImportDocHeader."File Name";
            if FileName = '' then
                FileName := 'Invoice_' + Format(ImportDocHeader."Entry No.") + '.png';
            FileExtension := LowerCase(FileName);
            if StrPos(FileExtension, '.') > 0 then
                FileExtension := CopyStr(FileExtension, StrPos(FileExtension, '.') + 1)
            else
                FileExtension := 'png';
            ImportDocHeader."Image Blob".CreateInStream(InStream);
        end;

        DocumentAttachment.Init();
        DocumentAttachment.Validate("Table ID", Database::"Purchase Header");
        DocumentAttachment.Validate("No.", PurchaseInvoiceNo);
        DocumentAttachment.Validate("Document Type", DocumentAttachment."Document Type"::Invoice);
        DocumentAttachment.Validate("File Name", CopyStr(FileName, 1, MaxStrLen(DocumentAttachment."File Name")));
        DocumentAttachment.Validate("File Extension", CopyStr(FileExtension, 1, MaxStrLen(DocumentAttachment."File Extension")));
        DocumentAttachment."Document Reference ID".ImportStream(InStream, FileName);
        DocumentAttachment.Insert(true);
    end;

    procedure VerifyVendorData(var ImportDocHeader: Record "PaperTide Import Doc. Header")
    var
        Vendor: Record Vendor;
        VendorBankAccount: Record "Vendor Bank Account";
        Messages: Text;
        VerifStatus: Enum "PaperTide Inv. Verif. Status";
        BankFound: Boolean;
    begin
        VerifStatus := VerifStatus::"Not Checked";
        Messages := '';

        // No vendor matched — unknown sender, needs manual review
        if ImportDocHeader."Vendor No." = '' then begin
            ImportDocHeader."Verification Status" := VerifStatus::Warning;
            ImportDocHeader."Verification Messages" := 'No vendor match found. Manual verification required.';
            exit;
        end;

        if not Vendor.Get(ImportDocHeader."Vendor No.") then begin
            ImportDocHeader."Verification Status" := VerifStatus::Warning;
            ImportDocHeader."Verification Messages" := 'Matched vendor no longer exists.';
            exit;
        end;

        // Start with Verified, downgrade if issues found
        VerifStatus := VerifStatus::Verified;

        // CHECK 1: VAT Registration No. mismatch
        if ImportDocHeader."Vendor VAT No." <> '' then begin
            if Vendor."VAT Registration No." = '' then begin
                Messages += 'Vendor has no VAT No. on file — cannot verify. ';
                if VerifStatus.AsInteger() < VerifStatus::Warning.AsInteger() then
                    VerifStatus := VerifStatus::Warning;
            end else
                if UpperCase(ImportDocHeader."Vendor VAT No.") <> UpperCase(Vendor."VAT Registration No.") then begin
                    Messages += 'VAT No. mismatch! Invoice: ' + ImportDocHeader."Vendor VAT No." +
                        ', Vendor card: ' + Vendor."VAT Registration No." + '. ';
                    VerifStatus := VerifStatus::Suspicious;
                end;
        end;

        // CHECK 2: Bank account / IBAN mismatch
        if ImportDocHeader."Vendor Bank Account" <> '' then begin
            BankFound := false;
            VendorBankAccount.SetRange("Vendor No.", Vendor."No.");
            if VendorBankAccount.FindSet() then
                repeat
                    if (UpperCase(VendorBankAccount.IBAN) = UpperCase(ImportDocHeader."Vendor Bank Account")) or
                       (UpperCase(VendorBankAccount."Bank Account No.") = UpperCase(ImportDocHeader."Vendor Bank Account")) then
                        BankFound := true;
                until (VendorBankAccount.Next() = 0) or BankFound;

            if not BankFound then begin
                VendorBankAccount.Reset();
                VendorBankAccount.SetRange("Vendor No.", Vendor."No.");
                if VendorBankAccount.IsEmpty() then begin
                    Messages += 'Vendor has no bank accounts on file — cannot verify payment details. ';
                    if VerifStatus.AsInteger() < VerifStatus::Warning.AsInteger() then
                        VerifStatus := VerifStatus::Warning;
                end else begin
                    Messages += 'BANK ACCOUNT NOT RECOGNIZED! Invoice: ' + ImportDocHeader."Vendor Bank Account" +
                        ' does not match any registered account for this vendor. ';
                    VerifStatus := VerifStatus::Suspicious;
                end;
            end;
        end;

        // CHECK 3: No VAT or bank info at all — cannot verify
        if (ImportDocHeader."Vendor VAT No." = '') and (ImportDocHeader."Vendor Bank Account" = '') then begin
            Messages += 'No VAT No. or bank account on invoice — cannot verify sender identity. ';
            if VerifStatus.AsInteger() < VerifStatus::Warning.AsInteger() then
                VerifStatus := VerifStatus::Warning;
        end;

        if Messages = '' then
            Messages := 'All extracted data matches vendor records.';

        ImportDocHeader."Verification Status" := VerifStatus;
        ImportDocHeader."Verification Messages" := CopyStr(Messages, 1, 2048);
    end;

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
        ValueText: Text;
        Result: Decimal;
    begin
        if not JsonObj.Get(FieldName, JsonToken) then
            exit(0);

        if JsonToken.AsValue().IsNull() then
            exit(0);

        // First try to get as number (works when AI returns numeric value)
        ValueText := JsonToken.AsValue().AsText();

        // Evaluate handles both numeric strings and actual numbers converted to text
        if Evaluate(Result, ValueText) then
            exit(Result);

        exit(0);
    end;

    local procedure GetJsonDateValue(JsonObj: JsonObject; FieldName: Text): Date
    var
        JsonToken: JsonToken;
        DateText: Text;
        ParsedDate: Date;
    begin
        if not JsonObj.Get(FieldName, JsonToken) then
            exit(0D);

        if JsonToken.AsValue().IsNull() then
            exit(0D);

        DateText := JsonToken.AsValue().AsText();
        if DateText = '' then
            exit(0D);

        // Try parsing using Business Central's regional settings
        // Format 9 = XML format (YYYY-MM-DD)
        if Evaluate(ParsedDate, DateText, 9) then
            exit(ParsedDate);

        // Format 1 = Windows regional settings (respects user's locale)
        if Evaluate(ParsedDate, DateText, 1) then
            exit(ParsedDate);

        // Fallback: Try common formats manually
        exit(TryParseDateManually(DateText));
    end;

    local procedure TryParseDateManually(DateText: Text): Date
    var
        Year: Integer;
        Month: Integer;
        Day: Integer;
    begin
        DateText := DateText.Trim();

        // ISO format: YYYY-MM-DD or YYYY/MM/DD
        if StrLen(DateText) >= 10 then begin
            if (DateText[5] in ['-', '/']) and (DateText[8] in ['-', '/']) then begin
                if Evaluate(Year, CopyStr(DateText, 1, 4)) and
                   Evaluate(Month, CopyStr(DateText, 6, 2)) and
                   Evaluate(Day, CopyStr(DateText, 9, 2)) then
                    if (Year > 1900) and (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= 31) then
                        exit(DMY2Date(Day, Month, Year));
            end;
        end;

        // European format: DD-MM-YYYY or DD/MM/YYYY
        if StrLen(DateText) >= 10 then begin
            if (DateText[3] in ['-', '/']) and (DateText[6] in ['-', '/']) then begin
                if Evaluate(Day, CopyStr(DateText, 1, 2)) and
                   Evaluate(Month, CopyStr(DateText, 4, 2)) and
                   Evaluate(Year, CopyStr(DateText, 7, 4)) then
                    if (Year > 1900) and (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= 31) then
                        exit(DMY2Date(Day, Month, Year));
            end;
        end;

        // US format: MM-DD-YYYY or MM/DD/YYYY
        if StrLen(DateText) >= 10 then begin
            if (DateText[3] in ['-', '/']) and (DateText[6] in ['-', '/']) then begin
                if Evaluate(Month, CopyStr(DateText, 1, 2)) and
                   Evaluate(Day, CopyStr(DateText, 4, 2)) and
                   Evaluate(Year, CopyStr(DateText, 7, 4)) then
                    if (Year > 1900) and (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= 31) then
                        exit(DMY2Date(Day, Month, Year));
            end;
        end;

        // Short year formats - assume 2000s for years < 50, 1900s for years >= 50
        // DD-MM-YY or DD/MM/YY
        if StrLen(DateText) = 8 then begin
            if (DateText[3] in ['-', '/']) and (DateText[6] in ['-', '/']) then begin
                if Evaluate(Day, CopyStr(DateText, 1, 2)) and
                   Evaluate(Month, CopyStr(DateText, 4, 2)) and
                   Evaluate(Year, CopyStr(DateText, 7, 2)) then begin
                    if Year < 50 then
                        Year += 2000
                    else
                        Year += 1900;
                    if (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= 31) then
                        exit(DMY2Date(Day, Month, Year));
                end;
            end;
        end;

        exit(0D);
    end;
}
