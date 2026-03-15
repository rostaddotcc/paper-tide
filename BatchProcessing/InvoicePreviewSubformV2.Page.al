page 50102 "PaperTide Inv. Preview Subform"
{
    Caption = 'Lines';
    PageType = ListPart;
    SourceTable = "PaperTide Import Doc. Line";
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Line number';
                    Editable = false;
                    Width = 6;
                }
                field(Type; Rec.Type)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the type of the line item (G/L Account, Item, etc.)';
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of the G/L Account, Item, etc.';
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Description of the line item';
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Quantity of the line item';
                    BlankZero = true;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Unit Price"; Rec."Unit Price")
                {
                    ApplicationArea = All;
                    ToolTip = 'Unit price of the line item';
                    BlankZero = true;
                    AutoFormatType = 2;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Line Amount"; Rec."Line Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total amount for the line';
                    BlankZero = true;
                    AutoFormatType = 1;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("VAT %"; Rec."VAT %")
                {
                    ApplicationArea = All;
                    ToolTip = 'VAT percentage for the line';
                    BlankZero = true;
                    Visible = false;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("GL Suggestion Confidence"; Rec."GL Suggestion Confidence")
                {
                    ApplicationArea = All;
                    ToolTip = 'Confidence level of the AI GL account suggestion';
                    Editable = false;
                    StyleExpr = ConfidenceStyle;
                    Width = 8;
                }
                field("GL Suggestion Reason"; Rec."GL Suggestion Reason")
                {
                    ApplicationArea = All;
                    ToolTip = 'Reason for the suggested GL account';
                    Editable = false;
                    Visible = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec."GL Suggestion Confidence" of
            'High':
                ConfidenceStyle := 'Favorable';
            'Medium':
                ConfidenceStyle := 'Ambiguous';
            'Low':
                ConfidenceStyle := 'Unfavorable';
            else
                ConfidenceStyle := 'None';
        end;
    end;

    var
        ConfidenceStyle: Text;
}
