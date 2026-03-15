permissionset 50100 "PaperTide"
{
    Assignable = true;
    Caption = 'PaperTide';

    Permissions =
        tabledata "PaperTide AI Setup" = RIMD,
        tabledata "PaperTide Temp Invoice Buffer" = RIMD,
        tabledata "PaperTide Import Doc. Header" = RIMD,
        tabledata "PaperTide Import Doc. Line" = RIMD,
        tabledata "PaperTide Vendor Name Mapping" = RIMD,
        table "PaperTide AI Setup" = X,
        table "PaperTide Temp Invoice Buffer" = X,
        table "PaperTide Import Doc. Header" = X,
        table "PaperTide Import Doc. Line" = X,
        table "PaperTide Vendor Name Mapping" = X,
        page "PaperTide AI Setup" = X,
        page "PaperTide Invoice Preview" = X,
        page "PaperTide Batch Upload" = X,
        page "PaperTide Import Documents" = X,
        page "PaperTide Inv. Preview Subform" = X,
        page "PaperTide Inv. Image FactBox" = X,
        page "PaperTide Vendor Mappings" = X,
        codeunit "PaperTide AI Vision API" = X,
        codeunit "PaperTide Invoice Extraction" = X,
        codeunit "PaperTide Batch Processing Mgt" = X,
        codeunit "PaperTide Batch API Worker" = X,
        codeunit "PaperTide GL Account Predictor" = X;
}
