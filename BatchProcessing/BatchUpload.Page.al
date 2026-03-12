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

                field(PendingCount; GetPendingCount())
                {
                    Caption = 'Pending';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(ProcessingCount; GetProcessingCount())
                {
                    Caption = 'Processing';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(ReadyCount; GetReadyCount())
                {
                    Caption = 'Ready for Review';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Favorable;
                }
                field(ErrorCount; GetErrorCount())
                {
                    Caption = 'Errors';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Unfavorable;
                }
                field(CreatedCount; GetCreatedCount())
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

            if IsValidImageExtension(FileExtension) then begin
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
        OutStream: OutStream;
        MimeType: Text;
    begin
        // Determine MIME type
        MimeType := GetMimeType(FileName);

        // Create header record
        ImportDocHeader.Init();
        ImportDocHeader."File Name" := CopyStr(FileName, 1, 250);
        ImportDocHeader."Media ID" := CreateGuid();
        ImportDocHeader.Status := ImportDocHeader.Status::Pending;
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Pending;

        // Save image to blob
        ImportDocHeader."Image Blob".CreateOutStream(OutStream);
        CopyStream(OutStream, InStream);

        ImportDocHeader.Insert(true);

        exit(true);
    end;

    local procedure IsValidImageExtension(FileExtension: Text): Boolean
    begin
        exit(FileExtension in ['jpg', 'jpeg', 'png']);
    end;

    local procedure GetMimeType(FileName: Text): Text
    var
        FileExtension: Text;
    begin
        FileExtension := LowerCase(FileName);

        if FileExtension.EndsWith('.jpg') or FileExtension.EndsWith('.jpeg') then
            exit('image/jpeg');
        if FileExtension.EndsWith('.png') then
            exit('image/png');

        exit('application/octet-stream');
    end;

    local procedure StartAutoProcessing()
    var
        BatchProcessingMgt: Codeunit "Batch Processing Mgt";
    begin
        // Start processing pending documents with concurrency control
        BatchProcessingMgt.StartProcessingWithConcurrency();
    end;

    local procedure UpdateStatusCounts()
    begin
        HasPendingDocuments := (GetPendingCount() + GetProcessingCount() + GetReadyCount() + GetErrorCount() + GetCreatedCount()) > 0;
    end;

    local procedure GetPendingCount(): Integer
    var
        ImportDocHeader: Record "Import Document Header";
    begin
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Pending);
        exit(ImportDocHeader.Count());
    end;

    local procedure GetProcessingCount(): Integer
    var
        ImportDocHeader: Record "Import Document Header";
    begin
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Processing);
        exit(ImportDocHeader.Count());
    end;

    local procedure GetReadyCount(): Integer
    var
        ImportDocHeader: Record "Import Document Header";
    begin
        ImportDocHeader.SetRange(Status, ImportDocHeader.Status::Ready);
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Completed);
        exit(ImportDocHeader.Count());
    end;

    local procedure GetErrorCount(): Integer
    var
        ImportDocHeader: Record "Import Document Header";
    begin
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Error);
        exit(ImportDocHeader.Count());
    end;

    local procedure GetCreatedCount(): Integer
    var
        ImportDocHeader: Record "Import Document Header";
    begin
        ImportDocHeader.SetRange(Status, ImportDocHeader.Status::Created);
        exit(ImportDocHeader.Count());
    end;

    var
        HasPendingDocuments: Boolean;
}
