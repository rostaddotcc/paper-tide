table 50102 "PaperTide Import Doc. Header"
{
    Caption = 'PaperTide Import Doc. Header';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }
        field(2; "File Name"; Text[250])
        {
            Caption = 'File Name';
            DataClassification = CustomerContent;
        }
        field(3; "Import DateTime"; DateTime)
        {
            Caption = 'Import DateTime';
            DataClassification = SystemMetadata;
        }
        field(4; "Imported By"; Code[50])
        {
            Caption = 'Imported By';
            DataClassification = SystemMetadata;
            TableRelation = User."User Name";
        }
        field(5; Status; Enum "PaperTide Import Doc. Status")
        {
            Caption = 'Status';
            DataClassification = SystemMetadata;
            InitValue = Pending;
        }
        field(6; "Processing Status"; Enum "PaperTide Import Proc. Status")
        {
            Caption = 'Processing Status';
            DataClassification = SystemMetadata;
            InitValue = Pending;
        }
        field(7; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
            DataClassification = SystemMetadata;
        }
        field(8; "Created Invoice No."; Code[20])
        {
            Caption = 'Created Invoice No.';
            DataClassification = SystemMetadata;
            TableRelation = "Purchase Header"."No." where("Document Type" = const(Invoice));
        }
        field(9; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            DataClassification = CustomerContent;
            TableRelation = Vendor;
        }
        field(10; "Vendor Name"; Text[100])
        {
            Caption = 'Vendor Name';
            DataClassification = CustomerContent;
        }
        field(11; "Invoice No."; Code[35])
        {
            Caption = 'Invoice No.';
            DataClassification = CustomerContent;
        }
        field(12; "Invoice Date"; Date)
        {
            Caption = 'Invoice Date';
            DataClassification = CustomerContent;
        }
        field(13; "Due Date"; Date)
        {
            Caption = 'Due Date';
            DataClassification = CustomerContent;
        }
        field(14; "Amount Incl. VAT"; Decimal)
        {
            Caption = 'Amount Incl. VAT';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }
        field(15; "Amount Excl. VAT"; Decimal)
        {
            Caption = 'Amount Excl. VAT';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }
        field(16; "VAT Amount"; Decimal)
        {
            Caption = 'VAT Amount';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }
        field(17; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency;
        }
        field(20; "Media ID"; Guid)
        {
            Caption = 'Media ID';
            DataClassification = CustomerContent;
        }
        field(21; "Image Blob"; Blob)
        {
            Caption = 'Image Blob';
            DataClassification = CustomerContent;
            Subtype = Bitmap;
        }
        field(25; "Invoice Image"; Media)
        {
            Caption = 'Invoice Image';
            DataClassification = CustomerContent;
        }
        field(22; "Reference No."; Code[35])
        {
            Caption = 'Reference No.';
            DataClassification = CustomerContent;
        }
        field(23; "Payment Terms Code"; Code[10])
        {
            Caption = 'Payment Terms Code';
            DataClassification = CustomerContent;
            TableRelation = "Payment Terms";
        }
        field(24; "Payment Method Code"; Code[10])
        {
            Caption = 'Payment Method Code';
            DataClassification = CustomerContent;
            TableRelation = "Payment Method";
        }
        field(29; "Vendor VAT No."; Text[20])
        {
            Caption = 'Vendor VAT No.';
            DataClassification = CustomerContent;
            ToolTip = 'VAT registration number extracted from the invoice';
        }
        field(30; "Vendor Bank Account"; Text[50])
        {
            Caption = 'Vendor Bank Account';
            DataClassification = CustomerContent;
            ToolTip = 'Bank account or IBAN extracted from the invoice';
        }
        field(26; "PO Number"; Code[35])
        {
            Caption = 'PO Number';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the purchase order number extracted from the invoice';
        }
        field(27; "Original PDF Blob"; Blob)
        {
            Caption = 'Original PDF Blob';
            DataClassification = CustomerContent;
        }
        field(28; "Is PDF"; Boolean)
        {
            Caption = 'Is PDF';
            DataClassification = SystemMetadata;
        }
        field(31; "Verification Status"; Enum "PaperTide Inv. Verif. Status")
        {
            Caption = 'Verification Status';
            DataClassification = SystemMetadata;
            InitValue = "Not Checked";
            ToolTip = 'Indicates the result of fraud/verification checks against known vendor data';
        }
        field(32; "Verification Messages"; Text[2048])
        {
            Caption = 'Verification Messages';
            DataClassification = SystemMetadata;
            ToolTip = 'Details of verification warnings or issues found';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(StatusKey; Status, "Processing Status", "Import DateTime")
        {
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "File Name", "Vendor Name", "Invoice No.", Status)
        {
        }
    }

    trigger OnInsert()
    begin
        "Import DateTime" := CurrentDateTime();
        "Imported By" := UserId();
    end;
}

enum 50100 "PaperTide Import Doc. Status"
{
    Extensible = true;

    value(0; Pending)
    {
        Caption = 'Pending';
    }
    value(1; Ready)
    {
        Caption = 'Ready for Review';
    }
    value(2; Created)
    {
        Caption = 'Invoice Created';
    }
    value(3; Discarded)
    {
        Caption = 'Discarded';
    }
}

enum 50101 "PaperTide Import Proc. Status"
{
    Extensible = true;

    value(0; Pending)
    {
        Caption = 'Pending';
    }
    value(1; Processing)
    {
        Caption = 'Processing';
    }
    value(2; Completed)
    {
        Caption = 'Completed';
    }
    value(3; Error)
    {
        Caption = 'Error';
    }
}

enum 50102 "PaperTide Inv. Verif. Status"
{
    Extensible = true;

    value(0; "Not Checked")
    {
        Caption = 'Not Checked';
    }
    value(1; Verified)
    {
        Caption = 'Verified';
    }
    value(2; Warning)
    {
        Caption = 'Warning';
    }
    value(3; Suspicious)
    {
        Caption = 'Suspicious';
    }
}
