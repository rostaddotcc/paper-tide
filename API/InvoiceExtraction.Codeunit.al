codeunit 50101 "Invoice Extraction"
{
    Access = Internal;

    procedure ParseAndFillBuffer(
        ExtractedData: JsonObject;
        MediaId: Guid;
        var TempBuffer: Record "Temp Invoice Buffer")
    var
        Vendor: Record Vendor;
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
        if VendorNo <> '' then begin
            if not Vendor.Get(VendorNo) then
                VendorNo := '';
        end;

        if (VendorNo = '') and (VendorName <> '') then begin
            Vendor.SetRange(Name, VendorName);
            if Vendor.FindFirst() then
                VendorNo := Vendor."No."
            else begin
                // Try partial match
                Vendor.SetFilter(Name, '@*' + VendorName + '*');
                if Vendor.FindFirst() then
                    VendorNo := Vendor."No.";
            end;
            Vendor.Reset();
        end;

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

    local procedure ParseAndInsertLine(
        var TempBuffer: Record "Temp Invoice Buffer";
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

    procedure CreatePurchaseInvoice(TempBuffer: Record "Temp Invoice Buffer"): Code[20]
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        TempLine: Record "Temp Invoice Buffer";
        AISetup: Record "AI Extraction Setup";
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
            Error('Vendor No. must be specified before creating invoice.');
        if TempBuffer."Invoice No." = '' then
            Error('Invoice No. must be specified before creating invoice.');

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
        end else begin
            // Create at least one blank line if no lines extracted
            PurchLine.Init();
            PurchLine."Document Type" := PurchHeader."Document Type";
            PurchLine."Document No." := PurchHeader."No.";
            PurchLine."Line No." := 10000;
            PurchLine.Validate(Type, PurchLine.Type::"G/L Account");
            // Use default G/L account from setup if configured
            if DefaultGLAccount <> '' then
                PurchLine.Validate("No.", DefaultGLAccount);
            PurchLine.Validate(Description, 'Invoice amount - please review and assign account');
            if TempBuffer."Amount Incl. VAT" <> 0 then
                PurchLine.Validate("Line Amount", TempBuffer."Amount Incl. VAT");
            PurchLine.Insert(true);
        end;

        exit(PurchHeader."No.");
    end;

    procedure ParseAndSaveToImportDoc(
        ExtractedData: JsonObject;
        var ImportDocHeader: Record "Import Document Header")
    var
        ImportDocLine: Record "Import Document Line";
        Vendor: Record Vendor;
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
        EntryNo: Integer;
    begin
        EntryNo := ImportDocHeader."Entry No.";

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

        // Try to find vendor by number or name
        if VendorNo <> '' then begin
            if not Vendor.Get(VendorNo) then
                VendorNo := '';
        end;

        if (VendorNo = '') and (VendorName <> '') then begin
            Vendor.SetRange(Name, VendorName);
            if Vendor.FindFirst() then
                VendorNo := Vendor."No."
            else begin
                // Try partial match
                Vendor.SetFilter(Name, '@*' + VendorName + '*');
                if Vendor.FindFirst() then
                    VendorNo := Vendor."No.";
            end;
            Vendor.Reset();
        end;

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

                // Calculate missing values
                if (ImportDocLine."Line Amount" = 0) and (ImportDocLine.Quantity > 0) and (ImportDocLine."Unit Price" > 0) then
                    ImportDocLine."Line Amount" := Round(ImportDocLine.Quantity * ImportDocLine."Unit Price", 0.01);

                ImportDocLine.Insert();
            end;
        end;
    end;

    procedure CreateInvoiceFromImportDoc(EntryNo: Integer): Code[20]
    var
        ImportDocHeader: Record "Import Document Header";
        ImportDocLine: Record "Import Document Line";
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        AISetup: Record "AI Extraction Setup";
        LineNo: Integer;
        DefaultGLAccount: Code[20];
    begin
        if not ImportDocHeader.Get(EntryNo) then
            Error('Import document not found');

        if ImportDocHeader.Status = ImportDocHeader.Status::Created then
            Error('Invoice already created for this document');

        // Get default G/L account from setup
        if AISetup.Get() then
            DefaultGLAccount := AISetup."Default G/L Account";

        // Validate required fields
        if ImportDocHeader."Vendor No." = '' then
            Error('Vendor No. must be specified before creating invoice.');
        if ImportDocHeader."Invoice No." = '' then
            Error('Invoice No. must be specified before creating invoice.');

        // Create purchase invoice header
        PurchHeader.Init();
        PurchHeader."Document Type" := PurchHeader."Document Type"::Invoice;
        PurchHeader.Validate("Buy-from Vendor No.", ImportDocHeader."Vendor No.");
        PurchHeader.Validate("Vendor Invoice No.", ImportDocHeader."Invoice No.");
        if ImportDocHeader."Invoice Date" <> 0D then
            PurchHeader.Validate("Document Date", ImportDocHeader."Invoice Date");
        if ImportDocHeader."Due Date" <> 0D then
            PurchHeader.Validate("Due Date", ImportDocHeader."Due Date");
        if ImportDocHeader."Payment Terms Code" <> '' then
            PurchHeader.Validate("Payment Terms Code", ImportDocHeader."Payment Terms Code");
        if ImportDocHeader."Payment Method Code" <> '' then
            PurchHeader.Validate("Payment Method Code", ImportDocHeader."Payment Method Code");
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
                PurchLine.Validate(Type, PurchLine.Type::"G/L Account");
                if DefaultGLAccount <> '' then
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
        end else begin
            // Create at least one blank line if no lines extracted
            PurchLine.Init();
            PurchLine."Document Type" := PurchHeader."Document Type";
            PurchLine."Document No." := PurchHeader."No.";
            PurchLine."Line No." := 10000;
            PurchLine.Validate(Type, PurchLine.Type::"G/L Account");
            if DefaultGLAccount <> '' then
                PurchLine.Validate("No.", DefaultGLAccount);
            PurchLine.Validate(Description, 'Invoice amount - please review and assign account');
            if ImportDocHeader."Amount Incl. VAT" <> 0 then
                PurchLine.Validate("Line Amount", ImportDocHeader."Amount Incl. VAT");
            PurchLine.Insert(true);
        end;

        // Update import document as created
        ImportDocHeader.Status := ImportDocHeader.Status::Created;
        ImportDocHeader."Created Invoice No." := PurchHeader."No.";
        ImportDocHeader.Modify();

        exit(PurchHeader."No.");
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
