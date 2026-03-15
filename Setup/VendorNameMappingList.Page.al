page 50106 "PaperTide Vendor Mappings"
{
    Caption = 'PaperTide Vendor Mappings';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "PaperTide Vendor Name Mapping";
    Editable = true;

    layout
    {
        area(Content)
        {
            repeater(Mappings)
            {
                field("Extracted Name"; Rec."Extracted Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The vendor name as extracted by AI';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The mapped Business Central vendor';
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The actual vendor name';
                }
                field("Usage Count"; Rec."Usage Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of times this mapping has been automatically used';
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'When this mapping was created';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Who created this mapping';
                }
            }
        }
    }
}
