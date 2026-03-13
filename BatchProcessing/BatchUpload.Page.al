page 50104 "Batch Upload"
{
    Caption = 'Batch Upload Invoices';
    PageType = Card;
    UsageCategory = Tasks;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Instructions)
            {
                Caption = 'Instructions';
                InstructionalText = 'Upload one or more invoice images (JPG, JPEG, PNG). The AI will extract data from each image. You can review and edit each invoice before creating it.';
            }

            group(QueueStatus)
            {
                Caption = 'Processing Queue';
                Visible = HasPendingDocuments;

                field(PendingCount; PendingCount)
                {
                    Caption = 'Pending';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(ProcessingCount; ProcessingCount)
                {
                    Caption = 'Processing';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(ReadyCount; ReadyCount)
                {
                    Caption = 'Ready for Review';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Favorable;
                }
                field(ErrorCount; ErrorCount)
                {
                    Caption = 'Errors';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Unfavorable;
                }
                field(CreatedCount; CreatedCount)
                {
                    Caption = 'Created Invoices';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Favorable;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(UploadFiles)
            {
                ApplicationArea = All;
                Caption = 'Select Files';
                ToolTip = 'Select invoice images to upload';
                Image = Import;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    UploadFilesWithDialog();
                end;
            }
            action(ViewQueue)
            {
                ApplicationArea = All;
                Caption = 'View Import Queue';
                ToolTip = 'View all imported documents';
                Image = List;
                Promoted = true;
                PromotedCategory = Process;
                RunObject = page "Import Document List";
            }
            action(AISetup)
            {
                ApplicationArea = All;
                Caption = 'AI Extraction Setup';
                ToolTip = 'Configure AI extraction settings';
                Image = Setup;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    Page.Run(Page::"AI Extraction Setup");
                end;
            }
            action(ProcessPending)
            {
                ApplicationArea = All;
                Caption = 'Process Pending';
                ToolTip = 'Start processing pending documents';
                Image = Start;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = HasPendingDocuments;

                trigger OnAction()
                var
                    BatchProcessingMgt: Codeunit "Batch Processing Mgt";
                begin
                    BatchProcessingMgt.ProcessNextPending();
                    CurrPage.Update();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        UpdateStatusCounts();
    end;

    trigger OnAfterGetRecord()
    begin
        UpdateStatusCounts();
    end;

    local procedure UploadFilesWithDialog()
    var
        TempBlob: Codeunit "Temp Blob";
        FileManagement: Codeunit "File Management";
        BatchProcessingMgt: Codeunit "Batch Processing Mgt";
        InStream: InStream;
        FileName: Text;
        FileExtension: Text;
        UploadCount: Integer;
    begin
        // Upload first file
        if not UploadIntoStream('Select Invoice Image', '', 'Image Files (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png', FileName, InStream) then
            exit;

        repeat
            FileExtension := LowerCase(FileManagement.GetExtension(FileName));

            if BatchProcessingMgt.IsValidImageExtension(FileExtension) then begin
                if ImportSingleFile(InStream, FileName) then
                    UploadCount += 1;
            end;

            // Ask for next file
            Clear(InStream);
            FileName := '';
        until not Confirm('Upload another file?', true);

        if UploadCount > 0 then begin
            Message('%1 file(s) queued for processing.', UploadCount);
            UpdateStatusCounts();

            // Auto-start processing
            StartAutoProcessing();
        end;
    end;

    local procedure ImportSingleFile(InStream: InStream; FileName: Text): Boolean
    var
        ImportDocHeader: Record "Import Document Header";
        FileManagement: Codeunit "File Management";
        BatchProcessingMgt: Codeunit "Batch Processing Mgt";
        OutStream: OutStream;
        MediaInStream: InStream;
        FileExtension: Text;
        MimeType: Text;
    begin
        // Determine MIME type
        FileExtension := LowerCase(FileManagement.GetExtension(FileName));
        MimeType := BatchProcessingMgt.GetMimeType(FileExtension);

        // Create header record
        ImportDocHeader.Init();
        ImportDocHeader."File Name" := CopyStr(FileName, 1, 250);
        ImportDocHeader."Media ID" := CreateGuid();
        ImportDocHeader.Status := ImportDocHeader.Status::Pending;
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Pending;

        // Save image to blob first
        ImportDocHeader."Image Blob".CreateOutStream(OutStream);
        CopyStream(OutStream, InStream);

        // Insert record first to get the record created
        ImportDocHeader.Insert(true);

        // Now read from blob and import to Media field
        ImportDocHeader.CalcFields("Image Blob");
        ImportDocHeader."Image Blob".CreateInStream(MediaInStream);
        ImportDocHeader."Invoice Image".ImportStream(MediaInStream, FileName, MimeType);
        ImportDocHeader.Modify(true);

        exit(true);
    end;

    local procedure StartAutoProcessing()
    var
        BatchProcessingMgt: Codeunit "Batch Processing Mgt";
    begin
        // Start processing pending documents with concurrency control
        BatchProcessingMgt.StartProcessingWithConcurrency();
    end;

    local procedure UpdateStatusCounts()
    var
        ImportDocHeader: Record "Import Document Header";
    begin
        PendingCount := 0;
        ProcessingCount := 0;
        ReadyCount := 0;
        ErrorCount := 0;
        CreatedCount := 0;

        if ImportDocHeader.FindSet() then
            repeat
                case ImportDocHeader."Processing Status" of
                    ImportDocHeader."Processing Status"::Pending:
                        PendingCount += 1;
                    ImportDocHeader."Processing Status"::Processing:
                        ProcessingCount += 1;
                    ImportDocHeader."Processing Status"::Completed:
                        if ImportDocHeader.Status = ImportDocHeader.Status::Ready then
                            ReadyCount += 1;
                    ImportDocHeader."Processing Status"::Error:
                        ErrorCount += 1;
                end;
                if ImportDocHeader.Status = ImportDocHeader.Status::Created then
                    CreatedCount += 1;
            until ImportDocHeader.Next() = 0;

        HasPendingDocuments := (PendingCount + ProcessingCount + ReadyCount + ErrorCount + CreatedCount) > 0;
    end;

    var
        HasPendingDocuments: Boolean;
        PendingCount: Integer;
        ProcessingCount: Integer;
        ReadyCount: Integer;
        ErrorCount: Integer;
        CreatedCount: Integer;
}
