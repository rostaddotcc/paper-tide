page 50103 "PaperTide Inv. Image FactBox"
{
    Caption = 'Original Image';
    PageType = CardPart;
    SourceTable = "PaperTide Import Doc. Header";

    layout
    {
        area(Content)
        {
            field(InvoiceImage; Rec."Invoice Image")
            {
                ApplicationArea = All;
                ShowCaption = false;
                ToolTip = 'Original invoice image for verification';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DownloadImage)
            {
                ApplicationArea = All;
                Caption = 'Download Image';
                ToolTip = 'Download the invoice image';
                Image = Export;
                Enabled = ImageAvailable;

                trigger OnAction()
                var
                    TenantMedia: Record "Tenant Media";
                    InStream: InStream;
                    FileName: Text;
                begin
                    if not Rec."Invoice Image".HasValue() then
                        exit;

                    // Get the media from Tenant Media table
                    TenantMedia.SetRange(ID, Rec."Invoice Image".MediaId());
                    if TenantMedia.FindFirst() then begin
                        TenantMedia.CalcFields(Content);
                        TenantMedia.Content.CreateInStream(InStream);

                        FileName := Rec."File Name";
                        if FileName = '' then
                            FileName := 'Invoice_' + Format(Rec."Entry No.") + '.png';

                        DownloadFromStream(InStream, 'Download Invoice Image', '', 'Image Files (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg', FileName);
                    end;
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ImageAvailable := Rec."Invoice Image".HasValue();
    end;

    var
        ImageAvailable: Boolean;
}
