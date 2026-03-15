table 50104 "Vendor Name Mapping"
{
    Caption = 'Vendor Name Mapping';
    DataClassification = CustomerContent;
    LookupPageId = "Vendor Name Mapping List";
    DrillDownPageId = "Vendor Name Mapping List";

    fields
    {
        field(1; "Extracted Name"; Text[100])
        {
            Caption = 'Extracted Name';
            DataClassification = CustomerContent;
            NotBlank = true;
            ToolTip = 'The vendor name as extracted by the AI from the invoice image';
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            DataClassification = CustomerContent;
            TableRelation = Vendor;
            NotBlank = true;
            ToolTip = 'The Business Central vendor number this name maps to';
        }
        field(3; "Vendor Name"; Text[100])
        {
            Caption = 'Vendor Name';
            FieldClass = FlowField;
            CalcFormula = lookup(Vendor.Name where("No." = field("Vendor No.")));
            Editable = false;
            ToolTip = 'The actual vendor name in Business Central';
        }
        field(10; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(11; "Created By"; Code[50])
        {
            Caption = 'Created By';
            DataClassification = SystemMetadata;
            TableRelation = User."User Name";
            Editable = false;
        }
        field(12; "Usage Count"; Integer)
        {
            Caption = 'Usage Count';
            DataClassification = SystemMetadata;
            Editable = false;
            InitValue = 0;
            ToolTip = 'Number of times this mapping has been used for automatic matching';
        }
    }

    keys
    {
        key(PK; "Extracted Name")
        {
            Clustered = true;
        }
        key(VendorKey; "Vendor No.")
        {
        }
    }

    trigger OnInsert()
    begin
        "Created DateTime" := CurrentDateTime();
        "Created By" := CopyStr(UserId(), 1, 50);
    end;
}
