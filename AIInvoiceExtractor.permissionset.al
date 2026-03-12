permissionset 50100 "AI Invoice Extractor"
{
    Assignable = true;
    Caption = 'AI Invoice Extractor';

    Permissions =
        tabledata "AI Extraction Setup" = RIMD,
        tabledata "Temp Invoice Buffer" = RIMD,
        tabledata "Import Document Header" = RIMD,
        tabledata "Import Document Line" = RIMD,
        table "AI Extraction Setup" = X,
        table "Temp Invoice Buffer" = X,
        table "Import Document Header" = X,
        table "Import Document Line" = X,
        page "AI Extraction Setup" = X,
        page "Invoice Preview" = X,
        page "Batch Upload" = X,
        page "Import Document List" = X,
        page "Invoice Preview Subform V2" = X,
        page "Invoice Image FactBox V2" = X,
        codeunit "Qwen VL API" = X,
        codeunit "Invoice Extraction" = X,
        codeunit "Batch Processing Mgt" = X,
        codeunit "Batch API Worker" = X;
}
