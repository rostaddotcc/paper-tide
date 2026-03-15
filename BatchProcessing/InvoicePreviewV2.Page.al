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
                field("Vendor VAT No."; Rec."Vendor VAT No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'VAT registration number extracted from the invoice';
                    Editable = IsEditable;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
                }
                field("Vendor Bank Account"; Rec."Vendor Bank Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Bank account or IBAN extracted from the invoice';
                    Editable = IsEditable;

                    trigger OnValidate()
                    begin
                        Rec.Modify();
                    end;
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
                field("PO Number"; Rec."PO Number")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the purchase order number extracted from the invoice';
                    Editable = IsEditable;

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
                field("Created Invoice No."; Rec."Created Invoice No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the purchase invoice created from this document';
                    Editable = false;
                    Style = Favorable;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        if Rec."Created Invoice No." <> '' then
                            OpenPurchaseInvoice(Rec."Created Invoice No.");
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

            group(Verification)
            {
                Caption = 'Fraud Detection';
                Editable = false;
                Visible = Rec."Verification Status".AsInteger() > 0;

                field("Verification Status"; Rec."Verification Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates the result of automated fraud checks';
                    StyleExpr = VerificationStyle;
                }
                field("Verification Messages"; Rec."Verification Messages")
                {
                    ApplicationArea = All;
                    ToolTip = 'Details of verification warnings or issues found';
                    MultiLine = true;
                    StyleExpr = VerificationStyle;
                }
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

                    // Block suspicious invoices unless explicitly overridden
                    if Rec."Verification Status" = Rec."Verification Status"::Suspicious then
                        if not Confirm(
                            'WARNING: This invoice has been flagged as SUSPICIOUS.\n\n%1\n\nAre you absolutely sure you want to create this invoice? This action will be logged.',
                            false,
                            Rec."Verification Messages") then
                            exit;

                    if Rec."Verification Status" = Rec."Verification Status"::Warning then
                        if not Confirm(
                            'This invoice has verification warnings:\n\n%1\n\nDo you want to proceed?',
                            false,
                            Rec."Verification Messages") then
                            exit;

                    if (Rec."Verification Status" <> Rec."Verification Status"::Suspicious) and
                       (Rec."Verification Status" <> Rec."Verification Status"::Warning) then
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
            action(RunVerification)
            {
                ApplicationArea = All;
                Caption = 'Verify';
                ToolTip = 'Re-run fraud detection checks against the current vendor and invoice data';
                Image = CheckDuplicates;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Enabled = not PageLocked;

                trigger OnAction()
                var
                    InvoiceExtraction: Codeunit "Invoice Extraction";
                begin
                    SaveChanges();
                    InvoiceExtraction.VerifyVendorData(Rec);
                    Rec.Modify();
                    CurrPage.Update(false);
                    case Rec."Verification Status" of
                        Rec."Verification Status"::Verified:
                            Message('Verification passed. All data matches vendor records.');
                        Rec."Verification Status"::Warning:
                            Message('Verification completed with warnings:\n%1', Rec."Verification Messages");
                        Rec."Verification Status"::Suspicious:
                            Message('SUSPICIOUS! Verification found issues:\n%1', Rec."Verification Messages");
                    end;
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
        InvoiceExtraction: Codeunit "Invoice Extraction";
    begin
        if Vendor.Get(Rec."Vendor No.") then begin
            SaveVendorNameMapping(Rec."Vendor Name", Rec."Vendor No.", Vendor.Name);
            Rec."Vendor Name" := Vendor.Name;
            // Re-run verification against the newly selected vendor
            InvoiceExtraction.VerifyVendorData(Rec);
            Rec.Modify();
            CurrPage.Update(false);
        end;
    end;

    local procedure SaveVendorNameMapping(ExtractedName: Text[100]; VendorNo: Code[20]; ActualVendorName: Text[100])
    var
        VendorNameMapping: Record "Vendor Name Mapping";
    begin
        if (ExtractedName = '') or (VendorNo = '') then
            exit;

        // Only save if extracted name differs from actual vendor name
        if UpperCase(ExtractedName) = UpperCase(ActualVendorName) then
            exit;

        if VendorNameMapping.Get(ExtractedName) then begin
            if VendorNameMapping."Vendor No." <> VendorNo then begin
                VendorNameMapping."Vendor No." := VendorNo;
                VendorNameMapping.Modify();
            end;
        end else begin
            VendorNameMapping.Init();
            VendorNameMapping."Extracted Name" := ExtractedName;
            VendorNameMapping."Vendor No." := VendorNo;
            VendorNameMapping.Insert(true);
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
            Error('An invoice from vendor %1 with number %2 already exists. Change the Invoice No. before creating.', Rec."Vendor No.", Rec."Invoice No.");

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
        VerificationStyle: Text;
}
