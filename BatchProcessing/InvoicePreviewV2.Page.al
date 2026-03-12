page 50101 "Invoice Preview"
{
    Caption = 'Invoice Preview';
    PageType = Card;
    SourceTable = "Import Document Header";
    DataCaptionExpression = Rec."File Name";
    InsertAllowed = false;
    DeleteAllowed = false;
    LinksAllowed = false;

    layout
    {
        area(Content)
        {
            group(Header)
            {
                Caption = 'Invoice Header';
                Editable = IsEditable;

                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor number';
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        UpdateVendorName();
                    end;
                }
                field("Vendor Name"; Rec."Vendor Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor name';
                    Editable = false;
                }
                field("Invoice No."; Rec."Invoice No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the vendor invoice number';
                    ShowMandatory = true;
                }
                field("Invoice Date"; Rec."Invoice Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the invoice date';

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Due Date"; Rec."Due Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the due date';

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the currency code';

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Reference No."; Rec."Reference No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reference number from the invoice';
                    Editable = IsEditable;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Payment Terms Code"; Rec."Payment Terms Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the payment terms code';
                    Editable = IsEditable;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Payment Method Code"; Rec."Payment Method Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the payment method code';
                    Editable = IsEditable;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
            }

            group(Amounts)
            {
                Caption = 'Amounts';
                Editable = IsEditable;

                field("Amount Excl. VAT"; Rec."Amount Excl. VAT")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the amount excluding VAT';

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("VAT Amount"; Rec."VAT Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the VAT amount';

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Amount Incl. VAT"; Rec."Amount Incl. VAT")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the amount including VAT';
                    Style = Strong;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
            }

            part(Lines; "Invoice Preview Subform V2")
            {
                ApplicationArea = All;
                Caption = 'Lines';
                SubPageLink = "Entry No." = field("Entry No.");
                Editable = IsEditable;
            }

            group(Metadata)
            {
                Caption = 'Document Information';
                Editable = false;

                field("File Name"; Rec."File Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the original file name';
                }
                field("Import DateTime"; Rec."Import DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the document was imported';
                }
                field("Imported By"; Rec."Imported By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies who imported the document';
                }
                field("Processing Status"; Rec."Processing Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current processing status';
                    StyleExpr = ProcessingStatusStyle;
                }
                field("Error Message Display"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the error message if processing failed';
                    Visible = HasError;
                    Style = Unfavorable;
                    MultiLine = true;
                }
            }
        }

        area(FactBoxes)
        {
            part(ImagePreview; "Invoice Image FactBox V2")
            {
                ApplicationArea = All;
                Caption = 'Original Image';
                SubPageLink = "Entry No." = field("Entry No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AcceptAndCreate)
            {
                ApplicationArea = All;
                Caption = 'Accept && Create Invoice';
                ToolTip = 'Create the purchase invoice with the current values';
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = CanCreateInvoice;

                trigger OnAction()
                var
                    InvoiceExtraction: Codeunit "Invoice Extraction";
                    InvoiceNo: Code[20];
                begin
                    if not ValidateBeforeCreate() then
                        exit;

                    if not Confirm('Create purchase invoice with these values?', false) then
                        exit;

                    // Save any pending changes first
                    SaveChanges();

                    InvoiceNo := InvoiceExtraction.CreateInvoiceFromImportDoc(Rec."Entry No.");

                    Message('Purchase Invoice %1 has been created.', InvoiceNo);

                    // Open the created invoice
                    OpenPurchaseInvoice(InvoiceNo);

                    CurrPage.Close();
                end;
            }
            action(ViewCreatedInvoice)
            {
                ApplicationArea = All;
                Caption = 'View Created Invoice';
                ToolTip = 'Open the created purchase invoice';
                Image = Document;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = PageLocked;
                Visible = PageLocked;

                trigger OnAction()
                begin
                    if Rec."Created Invoice No." <> '' then
                        OpenPurchaseInvoice(Rec."Created Invoice No.");
                end;
            }
            action(ToggleEdit)
            {
                ApplicationArea = All;
                Caption = 'Edit Values';
                ToolTip = 'Toggle editing of extracted values';
                Image = Edit;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = not PageLocked;

                trigger OnAction()
                begin
                    IsEditable := not IsEditable;
                    if IsEditable then
                        Message('Editing enabled. You can now modify the values.')
                    else
                        Message('Editing disabled. Values are locked.');
                end;
            }
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                ToolTip = 'Cancel without creating invoice';
                Image = Cancel;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    if Confirm('Close without creating invoice?', false) then
                        CurrPage.Close();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        // Lock page if invoice already created
        if Rec."Created Invoice No." <> '' then begin
            IsEditable := false;
            CanCreateInvoice := false;
            PageLocked := true;
            Message('This document has already been processed. Purchase Invoice %1 has been created.', Rec."Created Invoice No.");
        end else begin
            IsEditable := false;
            CanCreateInvoice := (Rec.Status = Rec.Status::Ready);
            PageLocked := false;
        end;
        LoadAmounts();
    end;

    trigger OnAfterGetRecord()
    begin
        // Lock page if invoice already created
        if Rec."Created Invoice No." <> '' then begin
            CanCreateInvoice := false;
            IsEditable := false;
            PageLocked := true;
        end else begin
            CanCreateInvoice := (Rec.Status = Rec.Status::Ready);
            PageLocked := false;
        end;

        // Set error visibility and processing status style
        HasError := Rec."Processing Status" = Rec."Processing Status"::Error;
        case Rec."Processing Status" of
            Rec."Processing Status"::Error:
                ProcessingStatusStyle := 'Unfavorable';
            Rec."Processing Status"::Completed:
                ProcessingStatusStyle := 'Favorable';
            Rec."Processing Status"::Processing:
                ProcessingStatusStyle := 'Strong';
            else
                ProcessingStatusStyle := 'None';
        end;

        LoadAmounts();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if IsEditable then
            SaveChanges();
        exit(true);
    end;

    local procedure LoadAmounts()
    var
        ImportDocLine: Record "Import Document Line";
    begin
        // Calculate totals from lines
        Rec."Amount Excl. VAT" := 0;
        Rec."VAT Amount" := 0;

        ImportDocLine.SetRange("Entry No.", Rec."Entry No.");
        if ImportDocLine.FindSet() then
            repeat
                Rec."Amount Excl. VAT" += ImportDocLine."Line Amount";
            until ImportDocLine.Next() = 0;

        // Calculate VAT
        if Rec."Amount Incl. VAT" > Rec."Amount Excl. VAT" then
            Rec."VAT Amount" := Rec."Amount Incl. VAT" - Rec."Amount Excl. VAT";
    end;

    local procedure UpdateVendorName()
    var
        Vendor: Record Vendor;
    begin
        if Vendor.Get(Rec."Vendor No.") then begin
            Rec."Vendor Name" := Vendor.Name;
            Rec.Modify();
        end;
    end;

    local procedure SaveChanges()
    begin
        Rec.Modify();
    end;

    local procedure ValidateBeforeCreate(): Boolean
    var
        Vendor: Record Vendor;
    begin
        if Rec."Vendor No." = '' then begin
            Error('Vendor No. is required.');
            exit(false);
        end;

        if not Vendor.Get(Rec."Vendor No.") then begin
            Error('Vendor %1 does not exist.', Rec."Vendor No.");
            exit(false);
        end;

        if Rec."Invoice No." = '' then begin
            Error('Invoice No. is required.');
            exit(false);
        end;

        // Check for duplicate vendor invoice no.
        if CheckDuplicateInvoiceNo(Rec."Vendor No.", Rec."Invoice No.") then
            if not Confirm('An invoice from this vendor with number %1 already exists. Continue anyway?', false, Rec."Invoice No.") then
                exit(false);

        exit(true);
    end;

    local procedure CheckDuplicateInvoiceNo(VendorNo: Code[20]; InvoiceNo: Code[35]): Boolean
    var
        PurchHeader: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
    begin
        // Check in open invoices
        PurchHeader.SetRange("Document Type", PurchHeader."Document Type"::Invoice);
        PurchHeader.SetRange("Buy-from Vendor No.", VendorNo);
        PurchHeader.SetRange("Vendor Invoice No.", InvoiceNo);
        if not PurchHeader.IsEmpty() then
            exit(true);

        // Check in posted invoices
        PurchInvHeader.SetRange("Buy-from Vendor No.", VendorNo);
        PurchInvHeader.SetRange("Vendor Invoice No.", InvoiceNo);
        if not PurchInvHeader.IsEmpty() then
            exit(true);

        exit(false);
    end;

    local procedure OpenPurchaseInvoice(InvoiceNo: Code[20])
    var
        PurchHeader: Record "Purchase Header";
    begin
        PurchHeader.Get(PurchHeader."Document Type"::Invoice, InvoiceNo);
        Page.Run(Page::"Purchase Invoice", PurchHeader);
    end;

    var
        IsEditable: Boolean;
        CanCreateInvoice: Boolean;
        PageLocked: Boolean;
        HasError: Boolean;
        ProcessingStatusStyle: Text;
}
