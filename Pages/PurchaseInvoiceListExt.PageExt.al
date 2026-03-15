pageextension 50100 "PaperTide Purch. Inv. List Ext" extends "Purchase Invoices"
{
    actions
    {
        addlast(Creation)
        {
            action(BatchUploadInvoices)
            {
                ApplicationArea = All;
                Caption = 'PaperTide Batch Upload';
                ToolTip = 'Upload multiple invoice images and process them with AI extraction';
                Image = Import;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    Page.Run(Page::"PaperTide Batch Upload");
                end;
            }
            action(ViewImportQueue)
            {
                ApplicationArea = All;
                Caption = 'View Import Queue';
                ToolTip = 'View all imported documents waiting for review';
                Image = List;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    Page.Run(Page::"PaperTide Import Documents");
                end;
            }
        }
    }
}
