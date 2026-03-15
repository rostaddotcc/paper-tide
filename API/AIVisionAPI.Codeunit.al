codeunit 50100 "AI Vision API"
{
    Access = Internal;

    var
        SetupNotConfiguredErr: Label 'AI Extraction Setup is not configured. Please configure API Base URL and API Key.';
        HttpRequestFailedErr: Label 'HTTP request failed with status code: %1\Error: %2';
        InvalidResponseErr: Label 'Invalid response from AI service: %1';
        RequestTimeoutErr: Label 'Request timed out after %1 ms. Please try again or increase timeout in setup.';
        ImageBase64ConversionErr: Label 'Failed to convert image to base64 format.';
        MediaIdNullErr: Label 'MediaId is null or empty.';
        ImportDocNotFoundErr: Label 'Import document not found for MediaId: %1';
        ImageBlobEmptyErr: Label 'Image Blob is empty for Import Document: %1';
        Base64EmptyResultErr: Label 'Base64 conversion failed - empty result.';

    procedure ExtractFromImage(MediaId: Guid; var ExtractedData: JsonObject): Boolean
    var
        Setup: Record "AI Extraction Setup";
        HttpClient: HttpClient;
        HttpRequest: HttpRequestMessage;
        HttpContent: HttpContent;
        HttpResponse: HttpResponseMessage;
        Headers: HttpHeaders;
        ContentHeaders: HttpHeaders;
        Base64Image: Text;
        RequestBody: Text;
        ResponseText: Text;
        ApiUrl: Text;
    begin
        Setup.GetOrCreateSetup();
        ValidateSetup(Setup);

        // Get base64 encoded image
        Base64Image := ConvertMediaToBase64(MediaId);
        if Base64Image = '' then
            Error(ImageBase64ConversionErr);

        // Build request body
        RequestBody := BuildRequestJson(Setup, Base64Image);

        // Configure HTTP client
        HttpClient.Timeout(Setup."Request Timeout (ms)");

        // Create request content
        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        // Create request with full URL
        HttpRequest.Method := 'POST';
        HttpRequest.SetRequestUri(Setup."API Base URL" + '/chat/completions');
        HttpRequest.Content(HttpContent);
        HttpRequest.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', Setup."API Key"));

        // Send request
        if not HttpClient.Send(HttpRequest, HttpResponse) then
            Error(RequestTimeoutErr, Setup."Request Timeout (ms)");

        // Check response
        if not HttpResponse.IsSuccessStatusCode() then begin
            HttpResponse.Content().ReadAs(ResponseText);
            Error(HttpRequestFailedErr, HttpResponse.HttpStatusCode(), ResponseText);
        end;

        // Parse response
        HttpResponse.Content().ReadAs(ResponseText);
        exit(ParseAIResponse(ResponseText, ExtractedData));
    end;

    procedure TestConnection(): Boolean
    var
        Setup: Record "AI Extraction Setup";
        HttpClient: HttpClient;
        HttpRequest: HttpRequestMessage;
        HttpResponse: HttpResponseMessage;
        Headers: HttpHeaders;
        ContentHeaders: HttpHeaders;
        HttpContent: HttpContent;
        RequestBody: Text;
    begin
        if not Setup.Get() then
            exit(false);

        if (Setup."API Base URL" = '') or (Setup."API Key" = '') then
            exit(false);

        // Simple test request with minimal payload
        RequestBody := '{' +
            '"model": "' + Setup."Model Name" + '",' +
            '"messages": [{' +
                '"role": "user",' +
                '"content": "test"' +
            '}],' +
            '"max_tokens": 5' +
        '}';

        // Create request content
        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        // Configure HTTP client
        HttpClient.Timeout(Setup."Request Timeout (ms)");

        // Create request with full URL
        HttpRequest.Method := 'POST';
        HttpRequest.SetRequestUri(Setup."API Base URL" + '/chat/completions');
        HttpRequest.Content(HttpContent);
        HttpRequest.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', Setup."API Key"));

        exit(HttpClient.Send(HttpRequest, HttpResponse) and HttpResponse.IsSuccessStatusCode());
    end;

    local procedure ValidateSetup(Setup: Record "AI Extraction Setup")
    begin
        if Setup."API Base URL" = '' then
            Error(SetupNotConfiguredErr);
        if Setup."API Key" = '' then
            Error(SetupNotConfiguredErr);
        if Setup."Model Name" = '' then
            Error(SetupNotConfiguredErr);
    end;

    local procedure ConvertMediaToBase64(MediaId: Guid) Base64String: Text
    var
        Base64Convert: Codeunit "Base64 Convert";
        ImportDocHeader: Record "Import Document Header";
        InStream: InStream;
    begin
        if IsNullGuid(MediaId) then
            Error(MediaIdNullErr);

        // Find import document by Media ID
        ImportDocHeader.SetRange("Media ID", MediaId);
        if not ImportDocHeader.FindFirst() then
            Error(ImportDocNotFoundErr, MediaId);

        if not ImportDocHeader."Image Blob".HasValue() then
            Error(ImageBlobEmptyErr, ImportDocHeader."Entry No.");

        // Read from blob
        ImportDocHeader.CalcFields("Image Blob");
        ImportDocHeader."Image Blob".CreateInStream(InStream);

        // Convert to base64
        Base64String := Base64Convert.ToBase64(InStream);

        if Base64String = '' then
            Error(Base64EmptyResultErr);
    end;

    local procedure BuildRequestJson(Setup: Record "AI Extraction Setup"; Base64Image: Text) RequestJson: Text
    var
        SystemPrompt: Text;
        JsonObj: JsonObject;
        MessagesArr: JsonArray;
        MessageObj: JsonObject;
        ContentArr: JsonArray;
        ContentObj: JsonObject;
        ImageObj: JsonObject;
        ImageUrlObj: JsonObject;
    begin
        SystemPrompt := Setup.GetSystemPromptWithChartOfAccounts();

        // Build message array
        // System message
        Clear(MessageObj);
        MessageObj.Add('role', 'system');
        MessageObj.Add('content', SystemPrompt);
        MessagesArr.Add(MessageObj);

        // User message with image
        Clear(MessageObj);
        MessageObj.Add('role', 'user');

        // Content array for multimodal
        Clear(ContentObj);
        ContentObj.Add('type', 'image_url');
        Clear(ImageUrlObj);
        ImageUrlObj.Add('url', StrSubstNo('data:image/jpeg;base64,%1', Base64Image));
        ContentObj.Add('image_url', ImageUrlObj);
        ContentArr.Add(ContentObj);

        MessageObj.Add('content', ContentArr);
        MessagesArr.Add(MessageObj);

        // Build main JSON object
        JsonObj.Add('model', Setup."Model Name");
        JsonObj.Add('messages', MessagesArr);
        JsonObj.Add('max_tokens', Setup."Max Tokens");
        JsonObj.Add('temperature', Setup.Temperature);

        JsonObj.WriteTo(RequestJson);
    end;

    local procedure ParseAIResponse(ResponseText: Text; var ExtractedData: JsonObject): Boolean
    var
        ResponseJson: JsonObject;
        ChoicesArr: JsonArray;
        ChoiceObj: JsonObject;
        MessageObj: JsonObject;
        ContentToken: JsonToken;
        ContentText: Text;
        ExtractedJson: JsonObject;
    begin
        if not ResponseJson.ReadFrom(ResponseText) then
            Error(InvalidResponseErr, 'Failed to parse JSON response');

        // Navigate to choices[0].message.content
        if not ResponseJson.Get('choices', ContentToken) then
            Error(InvalidResponseErr, 'Missing "choices" in response');

        ChoicesArr := ContentToken.AsArray();
        if ChoicesArr.Count() = 0 then
            Error(InvalidResponseErr, 'Empty choices array');

        ChoicesArr.Get(0, ContentToken);
        ChoiceObj := ContentToken.AsObject();

        if not ChoiceObj.Get('message', ContentToken) then
            Error(InvalidResponseErr, 'Missing "message" in choice');

        MessageObj := ContentToken.AsObject();

        if not MessageObj.Get('content', ContentToken) then
            Error(InvalidResponseErr, 'Missing "content" in message');

        ContentText := ContentToken.AsValue().AsText();

        // Parse the extracted JSON from AI response
        ContentText := CleanJsonResponse(ContentText);

        if not ExtractedData.ReadFrom(ContentText) then
            Error(InvalidResponseErr, 'AI response is not valid JSON: ' + ContentText);

        exit(true);
    end;

    local procedure CleanJsonResponse(ResponseText: Text) CleanText: Text
    begin
        CleanText := ResponseText;

        // Remove markdown code blocks if present (case-insensitive for ```json/```JSON)
        if CopyStr(CleanText, 1, 7).ToLower() = '```json' then
            CleanText := CleanText.Substring(8)
        else if CleanText.StartsWith('```') then
            CleanText := CleanText.Substring(4);
        if CleanText.EndsWith('```') then
            CleanText := CleanText.Substring(1, StrLen(CleanText) - 3);

        CleanText := CleanText.Trim();
    end;
}
