table 50101 "Temp Invoice Buffer"
{
    Caption = 'Temp Invoice Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = SystemMetadata;
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
            ValidateTableRelation = false;
            DataClassification = SystemMetadata;

            trigger OnValidate()
            var
                Vendor: Record Vendor;
            begin
                if Vendor.Get("Vendor No.") then
                    "Vendor Name" := Vendor.Name;
            end;
        }
        field(3; "Vendor Name"; Text[100])
        {
            Caption = 'Vendor Name';
            DataClassification = SystemMetadata;
        }
        field(4; "Invoice No."; Code[35])
        {
            Caption = 'Invoice No.';
            DataClassification = SystemMetadata;
        }
        field(5; "Invoice Date"; Date)
        {
            Caption = 'Invoice Date';
            DataClassification = SystemMetadata;
        }
        field(6; "Due Date"; Date)
        {
            Caption = 'Due Date';
            DataClassification = SystemMetadata;
        }
        field(7; "Amount Incl. VAT"; Decimal)
        {
            Caption = 'Amount Incl. VAT';
            DataClassification = SystemMetadata;
            AutoFormatType = 1;
        }
        field(8; "Amount Excl. VAT"; Decimal)
        {
            Caption = 'Amount Excl. VAT';
            DataClassification = SystemMetadata;
            AutoFormatType = 1;
        }
        field(9; "VAT Amount"; Decimal)
        {
            Caption = 'VAT Amount';
            DataClassification = SystemMetadata;
            AutoFormatType = 1;
        }
        field(10; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            TableRelation = Currency;
            ValidateTableRelation = false;
            DataClassification = SystemMetadata;
        }
        field(11; "Media ID"; Guid)
        {
            Caption = 'Media ID';
            DataClassification = SystemMetadata;
        }
        field(12; "Media Reference"; Text[50])
        {
            Caption = 'Media Reference';
            DataClassification = SystemMetadata;
        }
        // Line fields (for repeater)
        field(20; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = SystemMetadata;
        }
        field(21; "Line Description"; Text[100])
        {
            Caption = 'Description';
            DataClassification = SystemMetadata;
        }
        field(22; "Line Quantity"; Decimal)
        {
            Caption = 'Quantity';
            DataClassification = SystemMetadata;
            DecimalPlaces = 0 : 5;
        }
        field(23; "Line Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            DataClassification = SystemMetadata;
            AutoFormatType = 2;
        }
        field(24; "Line Amount"; Decimal)
        {
            Caption = 'Amount';
            DataClassification = SystemMetadata;
            AutoFormatType = 1;
        }
        field(25; "Line VAT %"; Decimal)
        {
            Caption = 'VAT %';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.", "Line No.")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }

    procedure ClearBuffer()
    begin
        DeleteAll();
    end;

    procedure SetHeaderValues(
        VendorNo: Code[20];
        VendorName: Text[100];
        InvoiceNo: Code[35];
        InvoiceDate: Date;
        DueDate: Date;
        AmountInclVAT: Decimal;
        AmountExclVAT: Decimal;
        VATAmount: Decimal;
        CurrencyCode: Code[10];
        MediaId: Guid)
    begin
        "Vendor No." := VendorNo;
        "Vendor Name" := VendorName;
        "Invoice No." := InvoiceNo;
        "Invoice Date" := InvoiceDate;
        "Due Date" := DueDate;
        "Amount Incl. VAT" := AmountInclVAT;
        "Amount Excl. VAT" := AmountExclVAT;
        "VAT Amount" := VATAmount;
        "Currency Code" := CurrencyCode;
        "Media ID" := MediaId;
        "Media Reference" := Format(MediaId);
    end;

    procedure AddLine(
        LineNo: Integer;
        Description: Text[100];
        Quantity: Decimal;
        UnitPrice: Decimal;
        LineAmount: Decimal)
    var
        TempBuffer: Record "Temp Invoice Buffer";
    begin
        TempBuffer.Copy(Rec);
        TempBuffer."Entry No." := "Entry No.";
        TempBuffer."Line No." := LineNo;
        TempBuffer."Line Description" := Description;
        TempBuffer."Line Quantity" := Quantity;
        TempBuffer."Line Unit Price" := UnitPrice;
        TempBuffer."Line Amount" := LineAmount;
        TempBuffer.Insert();
    end;
}
