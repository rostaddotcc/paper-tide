codeunit 50102 "PaperTide Batch Processing Mgt"
{
    Access = Internal;

    var
        MaxConcurrency: Integer;
        ConcurrencyErr: Label 'Cannot start processing: maximum concurrency limit reached.';
        StaleDocResetMsg: Label 'Document %1 (%2) was stuck in Processing for over %3 minutes and has been reset to Error.';

    local procedure GetMaxConcurrency(): Integer
    var
        Setup: Record "PaperTide AI Setup";
    begin
        if Setup.Get() and (Setup."Max Concurrency" > 0) then
            exit(Setup."Max Concurrency");
        exit(3);
    end;

    local procedure GetProcessingTimeoutMinutes(): Integer
    var
        Setup: Record "PaperTide AI Setup";
    begin
        if Setup.Get() and (Setup."Processing Timeout (min)" > 0) then
            exit(Setup."Processing Timeout (min)");
        exit(5);
    end;

    procedure StartProcessingWithConcurrency()
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        ActiveCount: Integer;
        SlotsAvailable: Integer;
        i: Integer;
    begin
        // Reset any stale documents first to free up slots
        ResetStaleDocuments();

        MaxConcurrency := GetMaxConcurrency();

        // Lock table to prevent race condition when multiple sessions check concurrency simultaneously
        ImportDocHeader.LockTable();

        // Count currently processing documents
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Processing);
        ActiveCount := ImportDocHeader.Count();

        if ActiveCount >= MaxConcurrency then
            exit; // Max concurrency reached

        // Calculate available slots
        SlotsAvailable := MaxConcurrency - ActiveCount;

        // Find pending documents and start processing
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Pending);
        ImportDocHeader.SetRange(Status, ImportDocHeader.Status::Pending);

        for i := 1 to SlotsAvailable do begin
            if ImportDocHeader.FindFirst() then
                StartProcessingDocument(ImportDocHeader)
            else
                break; // No more pending documents
        end;
    end;

    procedure ProcessNextPending()
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        ActiveCount: Integer;
    begin
        MaxConcurrency := GetMaxConcurrency();

        // Lock table to prevent race condition
        ImportDocHeader.LockTable();

        // Check concurrency limit
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Processing);
        ActiveCount := ImportDocHeader.Count();

        if ActiveCount >= MaxConcurrency then
            exit;

        // Find and process next pending
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Pending);
        ImportDocHeader.SetRange(Status, ImportDocHeader.Status::Pending);

        if ImportDocHeader.FindFirst() then
            StartProcessingDocument(ImportDocHeader);
    end;

    local procedure StartProcessingDocument(var ImportDocHeader: Record "PaperTide Import Doc. Header")
    var
        BatchAPIWorker: Codeunit "PaperTide Batch API Worker";
    begin
        // Update status to processing with timestamp
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Processing;
        ImportDocHeader."Processing Started At" := CurrentDateTime();
        ImportDocHeader.Modify();

        // Commit status change before processing so other sessions see the slot as taken
        Commit();

        BatchAPIWorker.ProcessDocument(ImportDocHeader."Entry No.");
    end;

    procedure RetryDocument(EntryNo: Integer)
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
    begin
        if ImportDocHeader.Get(EntryNo) then begin
            ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Pending;
            ImportDocHeader.Status := ImportDocHeader.Status::Pending;
            ImportDocHeader."Error Message" := '';
            ImportDocHeader."Processing Started At" := 0DT;
            ImportDocHeader.Modify();

            // Try to start processing immediately
            StartProcessingWithConcurrency();
        end;
    end;

    procedure ResetStaleDocuments()
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        TimeoutMinutes: Integer;
        TimeoutThreshold: DateTime;
    begin
        TimeoutMinutes := GetProcessingTimeoutMinutes();
        if TimeoutMinutes = 0 then
            exit; // Timeout detection disabled

        TimeoutThreshold := CurrentDateTime() - (TimeoutMinutes * 60 * 1000); // Convert minutes to milliseconds

        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Processing);
        if ImportDocHeader.FindSet() then
            repeat
                if (ImportDocHeader."Processing Started At" <> 0DT) and
                   (ImportDocHeader."Processing Started At" < TimeoutThreshold)
                then begin
                    ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Error;
                    ImportDocHeader."Error Message" := StrSubstNo(StaleDocResetMsg,
                        ImportDocHeader."Entry No.", ImportDocHeader."File Name", TimeoutMinutes);
                    ImportDocHeader."Processing Started At" := 0DT;
                    ImportDocHeader.Modify();
                end;
            until ImportDocHeader.Next() = 0;
    end;

    procedure ResetStuckDocument(EntryNo: Integer)
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
    begin
        if ImportDocHeader.Get(EntryNo) then
            if ImportDocHeader."Processing Status" = ImportDocHeader."Processing Status"::Processing then begin
                ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Error;
                ImportDocHeader."Error Message" := 'Manually reset from stuck Processing status.';
                ImportDocHeader."Processing Started At" := 0DT;
                ImportDocHeader.Modify();
            end;
    end;

    procedure GetActiveProcessingCount(): Integer
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
    begin
        ImportDocHeader.SetRange("Processing Status", ImportDocHeader."Processing Status"::Processing);
        exit(ImportDocHeader.Count());
    end;

    procedure IsConcurrencyAvailable(): Boolean
    begin
        exit(GetActiveProcessingCount() < GetMaxConcurrency());
    end;

    procedure IsValidImageExtension(FileExtension: Text): Boolean
    begin
        exit(FileExtension in ['jpg', 'jpeg', 'png']);
    end;

    procedure IsValidUploadExtension(FileExtension: Text): Boolean
    var
        Setup: Record "PaperTide AI Setup";
    begin
        if IsValidImageExtension(FileExtension) then
            exit(true);

        if FileExtension = 'pdf' then begin
            Setup.GetOrCreateSetup();
            exit(Setup."Enable PDF Conversion");
        end;

        exit(false);
    end;

    procedure IsPdfFile(FileExtension: Text): Boolean
    begin
        exit(FileExtension = 'pdf');
    end;

    procedure GetMimeType(FileExtension: Text): Text
    begin
        case FileExtension of
            'jpg', 'jpeg':
                exit('image/jpeg');
            'png':
                exit('image/png');
            'pdf':
                exit('application/pdf');
            else
                exit('application/octet-stream');
        end;
    end;
}
