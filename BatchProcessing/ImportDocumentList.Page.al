page 50105 "PaperTide Import Documents"
{
    Caption = 'PaperTide Import Queue';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "PaperTide Import Doc. Header";
    SourceTableView = sorting("Import DateTime") order(descending);
    CardPageId = "PaperTide Invoice Preview";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Documents)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entry number';
                    Visible = false;
                }
                field("File Name"; Rec."File Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the uploaded file';
                    StyleExpr = StatusStyle;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Document status';
                    StyleExpr = StatusStyle;
                }
                field("Processing Status"; Rec."Processing Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'AI processing status';
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Extracted vendor name';
                }
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Extracted invoice number';
                }
                field("Invoice Date"; Rec."Invoice Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Extracted invoice date';
                }
                field("PO Number"; Rec."PO Number")
                {
                    ApplicationArea = All;
                    ToolTip = 'Purchase order number from the invoice';
                    Visible = false;
                }
                field("Amount Incl. VAT"; Rec."Amount Incl. VAT")
                {
                    ApplicationArea = All;
                    ToolTip = 'Extracted amount including VAT';
                    BlankZero = true;
                }
                field("Verification Status"; Rec."Verification Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fraud detection verification result';
                    StyleExpr = VerificationStyle;
                }
                field("Created Invoice No."; Rec."Created Invoice No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Purchase invoice created from this document';
                    DrillDown = true;

                    trigger OnDrillDown()
                    var
                        PurchHeader: Record "Purchase Header";
                    begin
                        if Rec."Created Invoice No." <> '' then begin
                            PurchHeader.Get(PurchHeader."Document Type"::Invoice, Rec."Created Invoice No.");
                            Page.Run(Page::"Purchase Invoice", PurchHeader);
                        end;
                    end;
                }
                field("Import DateTime"; Rec."Import DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'When the document was imported';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Error message if processing failed';
                    Style = Unfavorable;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenPreview)
            {
                ApplicationArea = All;
                Caption = 'Review && Edit';
                ToolTip = 'Open the invoice preview to review and edit extracted data';
                Image = View;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = CanReview;

                trigger OnAction()
                begin
                    OpenPreviewPage();
                end;
            }
            action(CreateInvoice)
            {
                ApplicationArea = All;
                Caption = 'Create Invoice';
                ToolTip = 'Create purchase invoice from this document';
                Image = CreateDocument;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = CanCreateInvoice;

                trigger OnAction()
                var
                    InvoiceExtraction: Codeunit "PaperTide Invoice Extraction";
                begin
                    if Confirm('Create purchase invoice from %1?', false, Rec."File Name") then begin
                        InvoiceExtraction.CreateInvoiceFromImportDoc(Rec."Entry No.");
                        CurrPage.Update();
                    end;
                end;
            }
            action(RetryProcessing)
            {
                ApplicationArea = All;
                Caption = 'Retry';
                ToolTip = 'Retry processing this document';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = HasError;

                trigger OnAction()
                var
                    BatchProcessingMgt: Codeunit "PaperTide Batch Processing Mgt";
                begin
                    if Confirm('Retry processing %1?', false, Rec."File Name") then begin
                        BatchProcessingMgt.RetryDocument(Rec."Entry No.");
                        CurrPage.Update();
                    end;
                end;
            }
            action(DiscardDocument)
            {
                ApplicationArea = All;
                Caption = 'Discard';
                ToolTip = 'Mark this document as discarded';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = NotCreated;

                trigger OnAction()
                begin
                    if Confirm('Discard %1? This cannot be undone.', false, Rec."File Name") then begin
                        Rec.Status := Rec.Status::Discarded;
                        Rec.Modify();
                        CurrPage.Update();
                    end;
                end;
            }
            action(ResetStuck)
            {
                ApplicationArea = All;
                Caption = 'Reset Stuck';
                ToolTip = 'Manually reset a document that is stuck in Processing status';
                Image = ResetStatus;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = IsStuck;

                trigger OnAction()
                var
                    BatchProcessingMgt: Codeunit "PaperTide Batch Processing Mgt";
                begin
                    if Confirm('Reset document %1 from stuck Processing status? It will be marked as Error and can be retried.', false, Rec."File Name") then begin
                        BatchProcessingMgt.ResetStuckDocument(Rec."Entry No.");
                        CurrPage.Update();
                    end;
                end;
            }
            action(RefreshStatus)
            {
                ApplicationArea = All;
                Caption = 'Refresh';
                ToolTip = 'Refresh the list';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(ViewCreatedInvoice)
            {
                ApplicationArea = All;
                Caption = 'View Created Invoice';
                ToolTip = 'Open the created purchase invoice';
                Image = Document;
                Enabled = Rec."Created Invoice No." <> '';

                trigger OnAction()
                var
                    PurchHeader: Record "Purchase Header";
                begin
                    if Rec."Created Invoice No." <> '' then begin
                        PurchHeader.Get(PurchHeader."Document Type"::Invoice, Rec."Created Invoice No.");
                        Page.Run(Page::"Purchase Invoice", PurchHeader);
                    end;
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UpdateActionStates();
    end;

    trigger OnOpenPage()
    begin
        // Auto-refresh timer could be added here for real-time updates
    end;

    local procedure UpdateActionStates()
    begin
        // Can only review if document is ready/completed AND not already created
        CanReview := ((Rec.Status = Rec.Status::Ready) or
                     (Rec."Processing Status" = Rec."Processing Status"::Completed)) and
                     (Rec."Created Invoice No." = '');
        CanCreateInvoice := (Rec.Status = Rec.Status::Ready) and
                           (Rec."Created Invoice No." = '');
        HasError := Rec."Processing Status" = Rec."Processing Status"::Error;
        IsStuck := Rec."Processing Status" = Rec."Processing Status"::Processing;
        NotCreated := (Rec.Status <> Rec.Status::Created) and
                      (Rec."Created Invoice No." = '');

        // Set style based on status
        case Rec.Status of
            Rec.Status::Created:
                StatusStyle := 'Favorable';
            Rec.Status::Discarded:
                StatusStyle := 'Subordinate';
            Rec.Status::Ready:
                StatusStyle := 'Strong';
            else
                StatusStyle := 'None';
        end;

        // Set verification style
        case Rec."Verification Status" of
            Rec."Verification Status"::Verified:
                VerificationStyle := 'Favorable';
            Rec."Verification Status"::Warning:
                VerificationStyle := 'Ambiguous';
            Rec."Verification Status"::Suspicious:
                VerificationStyle := 'Unfavorable';
            else
                VerificationStyle := 'None';
        end;
    end;

    local procedure OpenPreviewPage()
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
    begin
        ImportDocHeader.Get(Rec."Entry No.");
        Page.Run(Page::"PaperTide Invoice Preview", ImportDocHeader);
    end;

    var
        CanReview: Boolean;
        CanCreateInvoice: Boolean;
        HasError: Boolean;
        IsStuck: Boolean;
        NotCreated: Boolean;
        StatusStyle: Text;
        VerificationStyle: Text;
}
