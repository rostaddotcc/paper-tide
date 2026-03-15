page 50104 "PaperTide Batch Upload"
{
    Caption = 'PaperTide Batch Upload';
    PageType = Card;
    UsageCategory = Tasks;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(DropZone)
            {
                Caption = 'Upload';
                InstructionalText = 'Drag and drop invoice files here, or click "Select Files" to browse. Supports JPG, JPEG, PNG and PDF.';
                FileUploadAction = UploadFiles;
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
            fileUploadAction(UploadFiles)
            {
                Caption = 'Select Files';
                ToolTip = 'Select one or more invoice images or PDF files to upload';
                Image = Import;
                AllowMultipleFiles = true;
                AllowedFileExtensions = '.jpg', '.jpeg', '.png', '.pdf';

                trigger OnAction(Files: List of [FileUpload])
                var
                    CurrentFile: FileUpload;
                    BatchProcessingMgt: Codeunit "PaperTide Batch Processing Mgt";
                    FileManagement: Codeunit "File Management";
                    InStream: InStream;
                    FileName: Text;
                    FileExtension: Text;
                    UploadCount: Integer;
                begin
                    foreach CurrentFile in Files do begin
                        FileName := CurrentFile.FileName();
                        FileExtension := LowerCase(FileManagement.GetExtension(FileName));

                        if BatchProcessingMgt.IsValidUploadExtension(FileExtension) then begin
                            CurrentFile.CreateInStream(InStream);
                            if ImportSingleFile(InStream, FileName) then
                                UploadCount += 1;
                        end;
                    end;

                    if UploadCount > 0 then begin
                        Message('%1 file(s) queued for processing.', UploadCount);
                        UpdateStatusCounts();
                        StartAutoProcessing();
                    end;
                end;
            }
            action(ViewQueue)
            {
                ApplicationArea = All;
                Caption = 'View Import Queue';
                ToolTip = 'View all imported documents';
                Image = List;
                RunObject = page "PaperTide Import Documents";
            }
            action(AISetup)
            {
                ApplicationArea = All;
                Caption = 'PaperTide AI Setup';
                ToolTip = 'Configure AI extraction settings';
                Image = Setup;

                trigger OnAction()
                begin
                    Page.Run(Page::"PaperTide AI Setup");
                end;
            }
            action(ProcessPending)
            {
                ApplicationArea = All;
                Caption = 'Process Pending';
                ToolTip = 'Start processing pending documents';
                Image = Start;
                Enabled = HasPendingDocuments;

                trigger OnAction()
                var
                    BatchProcessingMgt: Codeunit "PaperTide Batch Processing Mgt";
                begin
                    BatchProcessingMgt.ProcessNextPending();
                    CurrPage.Update();
                end;
            }
        }
        area(Promoted)
        {
            actionref(ViewQueueRef; ViewQueue)
            {
            }
            actionref(ProcessPendingRef; ProcessPending)
            {
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

    local procedure ImportSingleFile(InStream: InStream; FileName: Text): Boolean
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        FileManagement: Codeunit "File Management";
        BatchProcessingMgt: Codeunit "PaperTide Batch Processing Mgt";
        PDFConverter: Codeunit "PaperTide PDF Converter";
        ImageTempBlob: Codeunit "Temp Blob";
        PdfTempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        PdfOutStream: OutStream;
        MediaInStream: InStream;
        ImageInStream: InStream;
        PdfInStream: InStream;
        FileExtension: Text;
        MimeType: Text;
        IsPdf: Boolean;
    begin
        FileExtension := LowerCase(FileManagement.GetExtension(FileName));
        IsPdf := BatchProcessingMgt.IsPdfFile(FileExtension);

        if IsPdf then begin
            // Buffer the original PDF so we can use it for both conversion and storage
            PdfTempBlob.CreateOutStream(PdfOutStream);
            CopyStream(PdfOutStream, InStream);

            // Convert PDF to image using a fresh InStream from buffer
            PdfTempBlob.CreateInStream(PdfInStream);
            if not PDFConverter.TryConvertPdfToImage(PdfInStream, ImageTempBlob) then
                Error(GetLastErrorText());
            MimeType := 'image/png';
        end else
            MimeType := BatchProcessingMgt.GetMimeType(FileExtension);

        // Create header record
        ImportDocHeader.Init();
        ImportDocHeader."File Name" := CopyStr(FileName, 1, 250);
        ImportDocHeader."Media ID" := CreateGuid();
        ImportDocHeader.Status := ImportDocHeader.Status::Pending;
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Pending;

        // Save converted image (PNG) to blob for AI processing
        ImportDocHeader."Image Blob".CreateOutStream(OutStream);
        if IsPdf then begin
            ImageTempBlob.CreateInStream(ImageInStream);
            CopyStream(OutStream, ImageInStream);
        end else
            CopyStream(OutStream, InStream);

        // Save original PDF for attachment to created invoice
        if IsPdf then begin
            ImportDocHeader."Is PDF" := true;
            PdfTempBlob.CreateInStream(PdfInStream);
            ImportDocHeader."Original PDF Blob".CreateOutStream(PdfOutStream);
            CopyStream(PdfOutStream, PdfInStream);
        end;

        ImportDocHeader.Insert(true);

        // Import to Media field for preview
        ImportDocHeader.CalcFields("Image Blob");
        ImportDocHeader."Image Blob".CreateInStream(MediaInStream);
        ImportDocHeader."Invoice Image".ImportStream(MediaInStream, FileName, MimeType);
        ImportDocHeader.Modify(true);

        exit(true);
    end;

    local procedure StartAutoProcessing()
    var
        BatchProcessingMgt: Codeunit "PaperTide Batch Processing Mgt";
    begin
        BatchProcessingMgt.StartProcessingWithConcurrency();
    end;

    local procedure UpdateStatusCounts()
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
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
