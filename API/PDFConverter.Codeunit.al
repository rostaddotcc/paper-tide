codeunit 50104 "PaperTide PDF Converter"
{
    Access = Internal;

    var
        PdfConversionNotEnabledErr: Label 'PDF conversion is not enabled in PaperTide AI Setup.';
        PdfConverterNotConfiguredErr: Label 'PDF Converter Endpoint is not configured in PaperTide AI Setup.';
        PdfConversionFailedErr: Label 'PDF conversion failed with status code: %1';
        PdfConversionTimeoutErr: Label 'PDF conversion request timed out.';
        PdfConversionEmptyResponseErr: Label 'PDF conversion returned empty response.';

    procedure ConvertPdfToImage(var PdfInStream: InStream; var ImageTempBlob: Codeunit "Temp Blob"): Boolean
    var
        Setup: Record "PaperTide AI Setup";
        Base64Convert: Codeunit "Base64 Convert";
        HttpClient: HttpClient;
        HttpRequest: HttpRequestMessage;
        HttpResponse: HttpResponseMessage;
        HttpContent: HttpContent;
        ContentHeaders: HttpHeaders;
        BodyTempBlob: Codeunit "Temp Blob";
        BodyInStream: InStream;
        ResponseInStream: InStream;
        ImageOutStream: OutStream;
        PdfBase64: Text;
        Boundary: Text;
        EndpointUrl: Text;
    begin
        Setup.GetOrCreateSetup();
        ValidateSetup(Setup);

        // Convert PDF to base64
        PdfBase64 := Base64Convert.ToBase64(PdfInStream);

        // Build multipart request body
        Boundary := DelChr(Format(CreateGuid()), '=', '{}-');
        BuildMultipartBody(PdfBase64, Boundary, BodyTempBlob);

        // Build endpoint URL
        EndpointUrl := Setup."PDF Converter Endpoint";
        if EndpointUrl.EndsWith('/') then
            EndpointUrl := CopyStr(EndpointUrl, 1, StrLen(EndpointUrl) - 1);
        EndpointUrl += '/forms/chromium/screenshot/html';

        // Set up HTTP content from stream
        BodyTempBlob.CreateInStream(BodyInStream);
        HttpContent.WriteFrom(BodyInStream);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'multipart/form-data; boundary=' + Boundary);

        // Configure request
        HttpRequest.Method := 'POST';
        HttpRequest.SetRequestUri(EndpointUrl);
        HttpRequest.Content(HttpContent);
        HttpClient.Timeout(Setup."Request Timeout (ms)");

        // Send request
        if not HttpClient.Send(HttpRequest, HttpResponse) then
            Error(PdfConversionTimeoutErr);

        if not HttpResponse.IsSuccessStatusCode() then
            Error(PdfConversionFailedErr, HttpResponse.HttpStatusCode());

        // Read response (PNG image)
        HttpResponse.Content().ReadAs(ResponseInStream);
        ImageTempBlob.CreateOutStream(ImageOutStream);
        CopyStream(ImageOutStream, ResponseInStream);

        if not ImageTempBlob.HasValue() then
            Error(PdfConversionEmptyResponseErr);

        exit(true);
    end;

    [TryFunction]
    procedure TryConvertPdfToImage(var PdfInStream: InStream; var ImageTempBlob: Codeunit "Temp Blob")
    begin
        ConvertPdfToImage(PdfInStream, ImageTempBlob);
    end;

    procedure TestConnection(): Boolean
    var
        Setup: Record "PaperTide AI Setup";
        HttpClient: HttpClient;
        HttpResponse: HttpResponseMessage;
    begin
        if not Setup.Get() then
            exit(false);

        if Setup."PDF Converter Endpoint" = '' then
            exit(false);

        HttpClient.Timeout(10000);
        if not HttpClient.Get(Setup."PDF Converter Endpoint" + '/health', HttpResponse) then
            exit(false);

        exit(HttpResponse.IsSuccessStatusCode());
    end;

    local procedure ValidateSetup(Setup: Record "PaperTide AI Setup")
    begin
        if not Setup."Enable PDF Conversion" then
            Error(PdfConversionNotEnabledErr);
        if Setup."PDF Converter Endpoint" = '' then
            Error(PdfConverterNotConfiguredErr);
    end;

    local procedure BuildMultipartBody(PdfBase64: Text; Boundary: Text; var BodyTempBlob: Codeunit "Temp Blob")
    var
        TypeHelper: Codeunit "Type Helper";
        OutStream: OutStream;
        CrLf: Text;
    begin
        CrLf := TypeHelper.CRLFSeparator();
        BodyTempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);

        // Part 1: HTML file with embedded PDF
        OutStream.WriteText('--' + Boundary + CrLf);
        OutStream.WriteText('Content-Disposition: form-data; name="files"; filename="index.html"' + CrLf);
        OutStream.WriteText('Content-Type: text/html' + CrLf);
        OutStream.WriteText(CrLf);
        WriteHtmlTemplate(OutStream, PdfBase64);
        OutStream.WriteText(CrLf);

        // Part 2: format=png
        OutStream.WriteText('--' + Boundary + CrLf);
        OutStream.WriteText('Content-Disposition: form-data; name="format"' + CrLf);
        OutStream.WriteText(CrLf);
        OutStream.WriteText('png' + CrLf);

        // Part 3: waitForExpression
        OutStream.WriteText('--' + Boundary + CrLf);
        OutStream.WriteText('Content-Disposition: form-data; name="waitForExpression"' + CrLf);
        OutStream.WriteText(CrLf);
        OutStream.WriteText('window.pdfRendered===true' + CrLf);

        // Closing boundary
        OutStream.WriteText('--' + Boundary + '--' + CrLf);
    end;

    local procedure WriteHtmlTemplate(var OutStream: OutStream; PdfBase64: Text)
    begin
        // Write HTML in parts to avoid concatenating with the large base64 string
        OutStream.WriteText('<!DOCTYPE html><html><head>');
        OutStream.WriteText('<style>*{margin:0;padding:0;}body{background:white;}</style>');
        OutStream.WriteText('</head><body><canvas id="c"></canvas>');
        OutStream.WriteText('<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>');
        OutStream.WriteText('<script>');
        OutStream.WriteText('var pdfData=atob(''');
        OutStream.WriteText(PdfBase64);
        OutStream.WriteText(''');');
        OutStream.WriteText('var u=new Uint8Array(pdfData.length);');
        OutStream.WriteText('for(var i=0;i<pdfData.length;i++)u[i]=pdfData.charCodeAt(i);');
        OutStream.WriteText('pdfjsLib.GlobalWorkerOptions.workerSrc=');
        OutStream.WriteText('"https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js";');
        OutStream.WriteText('pdfjsLib.getDocument({data:u}).promise.then(function(pdf){');
        OutStream.WriteText('pdf.getPage(1).then(function(page){');
        OutStream.WriteText('var s=3;var vp=page.getViewport({scale:s});');
        OutStream.WriteText('var c=document.getElementById("c");');
        OutStream.WriteText('c.width=vp.width;c.height=vp.height;');
        OutStream.WriteText('page.render({canvasContext:c.getContext("2d"),viewport:vp}).promise.then(function(){');
        OutStream.WriteText('window.pdfRendered=true;');
        OutStream.WriteText('});});});');
        OutStream.WriteText('</script></body></html>');
    end;
}
