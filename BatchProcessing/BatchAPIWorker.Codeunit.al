codeunit 50103 "Batch API Worker"
{
    Access = Internal;

    var
        ProcessingErr: Label 'Error processing document %1: %2';
        LastErrorMsg: Text;

    procedure ProcessDocument(EntryNo: Integer)
    var
        ImportDocHeader: Record "Import Document Header";
        InvoiceExtraction: Codeunit "Invoice Extraction";
        ExtractedData: JsonObject;
        MediaId: Guid;
    begin
        if not ImportDocHeader.Get(EntryNo) then
            exit;

        // Ensure we have the media
        if IsNullGuid(ImportDocHeader."Media ID") then begin
            MarkAsError(ImportDocHeader, 'No image data found');
            exit;
        end;

        // Get the media GUID
        MediaId := ImportDocHeader."Media ID";

        // Call AI API with error handling via wrapper codeunit
        Clear(LastErrorMsg);
        if not ExtractFromImageWithErrorHandling(MediaId, ExtractedData) then begin
            MarkAsError(ImportDocHeader, LastErrorMsg);
            exit;
        end;

        // Parse and save to Import Document tables
        InvoiceExtraction.ParseAndSaveToImportDoc(ExtractedData, ImportDocHeader);

        // Mark as ready for review
        ImportDocHeader.Status := ImportDocHeader.Status::Ready;
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Completed;
        ImportDocHeader.Modify();

        // Try to process next pending document
        ProcessNextIfAvailable();
    end;

    [TryFunction]
    local procedure ExtractFromImageWithErrorHandling(MediaId: Guid; var ExtractedData: JsonObject)
    var
        QwenVLAPI: Codeunit "Qwen VL API";
    begin
        if not QwenVLAPI.ExtractFromImage(MediaId, ExtractedData) then
            Error('Failed to extract data from image');
    end;

    local procedure MarkAsError(var ImportDocHeader: Record "Import Document Header"; ErrorMsg: Text)
    begin
        ImportDocHeader."Processing Status" := ImportDocHeader."Processing Status"::Error;
        ImportDocHeader."Error Message" := CopyStr(ErrorMsg, 1, 2048);
        ImportDocHeader.Modify();

        // Try to process next pending document even if this one failed
        ProcessNextIfAvailable();
    end;

    local procedure ProcessNextIfAvailable()
    var
        BatchProcessingMgt: Codeunit "Batch Processing Mgt";
    begin
        // Start next pending document if concurrency allows
        if BatchProcessingMgt.IsConcurrencyAvailable() then
            BatchProcessingMgt.ProcessNextPending();
    end;
}
