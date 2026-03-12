pageextension 50100 "Purch. Invoice List Ext" extends "Purchase Invoices"
{
    actions
    {
        addlast(Creation)
        {
            action(BatchUploadInvoices)
            {
                ApplicationArea = All;
                Caption = 'Batch Upload Invoices';
                ToolTip = 'Upload multiple invoice images and process them with AI extraction';
                Image = Import;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    Page.Run(Page::"Batch Upload");
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
                    Page.Run(Page::"Import Document List");
                end;
            }
            action(UploadInvoiceImage)
            {
                ApplicationArea = All;
                Caption = 'Upload Single Invoice';
                ToolTip = 'Upload a single invoice image (legacy - use Batch Import for multiple)';
                Image = Import;
                Visible = false; // Hidden in favor of batch upload

                trigger OnAction()
                var
                    TempBlob: Codeunit "Temp Blob";
                    FileManagement: Codeunit "File Management";
                    InStream: InStream;
                    OutStream: OutStream;
                    FileName: Text;
                    FileExtension: Text;
                    DialogTitle: Text;
                    MimeType: Text;
                begin
                    DialogTitle := 'Select Invoice Image';

                    // Upload file using BC's file upload
                    if not UploadIntoStream(DialogTitle, '', 'Image Files (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png', FileName, InStream) then
                        exit;

                    // Validate file extension
                    FileExtension := LowerCase(FileManagement.GetExtension(FileName));

                    if not IsValidImageExtension(FileExtension) then begin
                        ShowInvalidFileMessage(FileExtension);
                        exit;
                    end;

                    // Determine MIME type
                    MimeType := GetMimeType(FileExtension);

                    // Process the image
                    ProcessInvoiceImage(InStream, FileName, MimeType);
                end;
            }
        }
    }

    local procedure IsValidImageExtension(FileExtension: Text): Boolean
    begin
        exit(FileExtension in ['jpg', 'jpeg', 'png']);
    end;

    local procedure ShowInvalidFileMessage(FileExtension: Text)
    begin
        if FileExtension = 'pdf' then
            Message('PDF files are not supported in version 1.0. Please convert your PDF to JPG or PNG format before uploading.\n\nTip: You can use "Print to PDF" from your PDF reader and select "Microsoft Print to PDF" with an image printer, or use an online converter.')
        else
            Error('Invalid file format: %1\n\nSupported formats: JPG, JPEG, PNG', FileExtension);
    end;

    local procedure GetMimeType(FileExtension: Text): Text
    begin
        case FileExtension of
            'jpg', 'jpeg':
                exit('image/jpeg');
            'png':
                exit('image/png');
            else
                exit('application/octet-stream');
        end;
    end;

    local procedure ProcessInvoiceImage(InStream: InStream; FileName: Text; MimeType: Text)
    var
        AISetup: Record "AI Extraction Setup";
        TempBuffer: Record "Temp Invoice Buffer";
        InvoiceExtraction: Codeunit "Invoice Extraction";
        ExtractedData: JsonObject;
        TempBlob: Codeunit "Temp Blob";
        MediaOutStream: OutStream;
        ConfirmMessage: Text;
        Dialog: Dialog;
        MediaId: Guid;
    begin
        // Check setup
        if not AISetup.Get() then begin
            if Confirm('AI Extraction Setup is not configured. Would you like to configure it now?', false) then
                Page.Run(Page::"AI Extraction Setup");
            exit;
        end;

        if (AISetup."API Base URL" = '') or (AISetup."API Key" = '') then begin
            if Confirm('AI Extraction Setup is incomplete. Would you like to complete the configuration?', false) then
                Page.Run(Page::"AI Extraction Setup");
            exit;
        end;

        // Confirm processing
        ConfirmMessage := StrSubstNo('Process invoice image "%1" with AI extraction?\n\nThis will:\n1. Upload the image to Qwen-VL AI\n2. Extract invoice data\n3. Show a preview for your review', FileName);

        if not Confirm(ConfirmMessage, false) then
            exit;

        // Show processing dialog
        Dialog.Open('Processing invoice image...\\Please wait while the AI extracts data.');

        // Import image to Media and process
        TempBlob.CreateOutStream(MediaOutStream);
        CopyStream(MediaOutStream, InStream);
        TempBlob.CreateInStream(InStream);

        // Import to Media and get the MediaId
        MediaId := ImportToMedia(InStream, FileName, MimeType);

        if IsNullGuid(MediaId) then begin
            Dialog.Close();
            Error('Failed to import image. Please try again.');
        end;

        // Call AI API with error handling
        if not ExtractFromImageWithDialogHandling(MediaId, ExtractedData, Dialog) then begin
            Error('Failed to extract data from image. Please check your AI Extraction Setup and try again.');
        end;

        Dialog.Close();

        // Parse and fill buffer
        InvoiceExtraction.ParseAndFillBuffer(ExtractedData, MediaId, TempBuffer);

        // Open preview page
        TempBuffer.Get(1, 0); // Get header record
        Page.Run(Page::"Invoice Preview", TempBuffer);
    end;

    local procedure ImportToMedia(InStream: InStream; FileName: Text; MimeType: Text): Guid
    var
        ImportDocHeader: Record "Import Document Header";
        OutStream: OutStream;
        NewGuid: Guid;
    begin
        NewGuid := CreateGuid();

        ImportDocHeader.Init();
        ImportDocHeader."File Name" := CopyStr(FileName, 1, 250);
        ImportDocHeader."Media ID" := NewGuid;
        ImportDocHeader.Status := ImportDocHeader.Status::Pending;
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Pending;
        ImportDocHeader."Image Blob".CreateOutStream(OutStream);
        CopyStream(OutStream, InStream);
        ImportDocHeader.Insert(true);

        exit(NewGuid);
    end;

    [TryFunction]
    local procedure ExtractFromImageWithDialogHandling(MediaId: Guid; var ExtractedData: JsonObject; var Dialog: Dialog)
    var
        QwenVLAPI: Codeunit "Qwen VL API";
    begin
        if not QwenVLAPI.ExtractFromImage(MediaId, ExtractedData) then begin
            Dialog.Close();
            Error('Failed to extract data from image');
        end;
    end;
}
