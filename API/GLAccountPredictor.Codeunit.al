codeunit 50106 "PaperTide GL Account Predictor"
{
    Access = Internal;

    var
        SetupNotConfiguredErr: Label 'Auto Coding is not configured. Please configure Coding API Base URL, Key, and Model in PaperTide AI Setup.';
        HttpRequestFailedErr: Label 'Coding API request failed with status code: %1\Error: %2';
        InvalidResponseErr: Label 'Invalid response from coding AI: %1';

    procedure PredictGLAccounts(EntryNo: Integer)
    var
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        ImportDocLine: Record "PaperTide Import Doc. Line";
        AISetup: Record "PaperTide AI Setup";
        RequestBody: Text;
        ResponseText: Text;
        ResponseJson: JsonArray;
    begin
        if not AISetup.Get() then
            exit;

        if not AISetup."Enable Auto Coding" then
            exit;

        if not ImportDocHeader.Get(EntryNo) then
            exit;

        ImportDocLine.SetRange("Entry No.", EntryNo);
        if ImportDocLine.IsEmpty() then
            exit;

        // Build request and call API
        RequestBody := BuildRequestBody(AISetup, ImportDocHeader, ImportDocLine);
        if not CallCodingAPI(AISetup, RequestBody, ResponseText) then
            exit;

        // Parse response
        if not ParseResponse(ResponseText, ResponseJson) then
            exit;

        // Apply predictions to import document lines
        ApplyPredictions(EntryNo, ResponseJson);
    end;

    [TryFunction]
    procedure TryPredictGLAccounts(EntryNo: Integer)
    begin
        PredictGLAccounts(EntryNo);
    end;

    procedure TestCodingConnection(): Boolean
    var
        AISetup: Record "PaperTide AI Setup";
        HttpClient: HttpClient;
        HttpRequest: HttpRequestMessage;
        HttpResponse: HttpResponseMessage;
        Headers: HttpHeaders;
        ContentHeaders: HttpHeaders;
        HttpContent: HttpContent;
        RequestBody: Text;
    begin
        if not AISetup.Get() then
            exit(false);

        if (AISetup."Coding API Base URL" = '') or (AISetup."Coding API Key" = '') then
            exit(false);

        RequestBody := '{' +
            '"model": "' + AISetup."Coding Model Name" + '",' +
            '"messages": [{' +
                '"role": "user",' +
                '"content": "test"' +
            '}],' +
            '"max_tokens": 5' +
        '}';

        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        HttpClient.Timeout(AISetup."Coding Request Timeout (ms)");

        HttpRequest.Method := 'POST';
        HttpRequest.SetRequestUri(AISetup."Coding API Base URL" + '/chat/completions');
        HttpRequest.Content(HttpContent);
        HttpRequest.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AISetup."Coding API Key"));

        exit(HttpClient.Send(HttpRequest, HttpResponse) and HttpResponse.IsSuccessStatusCode());
    end;

    local procedure BuildRequestBody(
        AISetup: Record "PaperTide AI Setup";
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        var ImportDocLine: Record "PaperTide Import Doc. Line"): Text
    var
        JsonObj: JsonObject;
        MessagesArr: JsonArray;
        SystemMsg: JsonObject;
        UserMsg: JsonObject;
        SystemPromptText: Text;
        UserMessageText: Text;
        ChartContext: Text;
        HistoryContext: Text;
    begin
        // Build system prompt with chart of accounts
        SystemPromptText := AISetup.GetCodingSystemPrompt();

        // Build user message with lines, history, and chart
        UserMessageText := BuildUserMessage(AISetup, ImportDocHeader, ImportDocLine);

        // Chart of accounts context
        ChartContext := AISetup.GetChartOfAccountsContext();
        if ChartContext = '' then begin
            ChartContext := AISetup.BuildChartOfAccountsContextV2();
        end;

        if ChartContext <> '' then
            UserMessageText += '\n\nChart of Accounts:\n' + ChartContext;

        // System message
        SystemMsg.Add('role', 'system');
        SystemMsg.Add('content', SystemPromptText);
        MessagesArr.Add(SystemMsg);

        // User message
        UserMsg.Add('role', 'user');
        UserMsg.Add('content', UserMessageText);
        MessagesArr.Add(UserMsg);

        // Build request
        JsonObj.Add('model', AISetup."Coding Model Name");
        JsonObj.Add('messages', MessagesArr);
        JsonObj.Add('max_tokens', AISetup."Coding Max Tokens");
        JsonObj.Add('temperature', AISetup."Coding Temperature");

        JsonObj.WriteTo(UserMessageText);
        exit(UserMessageText);
    end;

    local procedure BuildUserMessage(
        AISetup: Record "PaperTide AI Setup";
        ImportDocHeader: Record "PaperTide Import Doc. Header";
        var ImportDocLine: Record "PaperTide Import Doc. Line"): Text
    var
        Vendor: Record Vendor;
        VendorName: Text;
        Message: Text;
        LineIndex: Integer;
    begin
        // Vendor context
        if ImportDocHeader."Vendor No." <> '' then begin
            if Vendor.Get(ImportDocHeader."Vendor No.") then
                VendorName := Vendor.Name
            else
                VendorName := ImportDocHeader."Vendor Name";
            Message := 'Vendor: ' + VendorName + ' (' + ImportDocHeader."Vendor No." + ')';
        end else
            Message := 'Vendor: ' + ImportDocHeader."Vendor Name" + ' (unknown)';

        // Invoice lines
        Message += '\n\nInvoice Lines to classify:';
        LineIndex := 1;
        ImportDocLine.SetRange("Entry No.", ImportDocHeader."Entry No.");
        if ImportDocLine.FindSet() then
            repeat
                Message += '\n' + Format(LineIndex) + '. [Line ' + Format(ImportDocLine."Line No.") + '] "' +
                    ImportDocLine.Description + '"';
                if ImportDocLine.Quantity <> 0 then
                    Message += ' - Qty: ' + Format(ImportDocLine.Quantity);
                if ImportDocLine."Line Amount" <> 0 then
                    Message += ', Amount: ' + Format(ImportDocLine."Line Amount", 0, '<Precision,2:2><Standard Format,1>');
                LineIndex += 1;
            until ImportDocLine.Next() = 0;

        // Posting history
        if (ImportDocHeader."Vendor No." <> '') and (AISetup."Coding History Invoices" > 0) then begin
            Message += BuildPostingHistoryContext(ImportDocHeader."Vendor No.", AISetup."Coding History Invoices", AISetup."Coding History Days");
        end;

        exit(Message);
    end;

    local procedure BuildPostingHistoryContext(VendorNo: Code[20]; MaxInvoices: Integer; MaxDays: Integer): Text
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchInvLine: Record "Purch. Inv. Line";
        DimSetEntry: Record "Dimension Set Entry";
        GLAccount: Record "G/L Account";
        Context: Text;
        DimText: Text;
        AccountName: Text;
        InvoiceCount: Integer;
        LineCount: Integer;
    begin
        Context := '';
        InvoiceCount := 0;
        LineCount := 0;

        PurchInvHeader.SetRange("Buy-from Vendor No.", VendorNo);
        if MaxDays > 0 then
            PurchInvHeader.SetFilter("Posting Date", '>=%1', CalcDate('<-' + Format(MaxDays) + 'D>', Today()));
        PurchInvHeader.SetCurrentKey("Posting Date");
        // Sort descending to get most recent first
        PurchInvHeader.Ascending(false);

        if not PurchInvHeader.FindSet() then
            exit('');

        repeat
            PurchInvLine.SetRange("Document No.", PurchInvHeader."No.");
            PurchInvLine.SetFilter(Type, '<>%1', PurchInvLine.Type::" ");
            if PurchInvLine.FindSet() then
                repeat
                    // Get GL account name
                    AccountName := '';
                    if (PurchInvLine.Type = PurchInvLine.Type::"G/L Account") and (PurchInvLine."No." <> '') then
                        if GLAccount.Get(PurchInvLine."No.") then
                            AccountName := GLAccount.Name;

                    // Build dimension text
                    DimText := '';
                    if PurchInvLine."Dimension Set ID" <> 0 then begin
                        DimSetEntry.SetRange("Dimension Set ID", PurchInvLine."Dimension Set ID");
                        if DimSetEntry.FindSet() then
                            repeat
                                if DimText <> '' then
                                    DimText += ', ';
                                DimText += DimSetEntry."Dimension Code" + '=' + DimSetEntry."Dimension Value Code";
                            until DimSetEntry.Next() = 0;
                    end;

                    Context += '\n- "' + PurchInvLine.Description + '" → Account: ' + PurchInvLine."No.";
                    if AccountName <> '' then
                        Context += ' (' + AccountName + ')';
                    Context += ', Type: ' + Format(PurchInvLine.Type);
                    if PurchInvLine."No." <> '' then
                        if PurchInvLine.Type = PurchInvLine.Type::Item then
                            Context += ' (' + PurchInvLine."No." + ')';
                    if DimText <> '' then
                        Context += ', Dimensions: [' + DimText + ']';

                    LineCount += 1;
                until PurchInvLine.Next() = 0;

            InvoiceCount += 1;
        until (PurchInvHeader.Next() = 0) or (InvoiceCount >= MaxInvoices);

        if Context = '' then
            exit('');

        exit('\n\nPosting History (last ' + Format(InvoiceCount) + ' invoices from this vendor):' + Context);
    end;

    local procedure CallCodingAPI(
        AISetup: Record "PaperTide AI Setup";
        RequestBody: Text;
        var ResponseText: Text): Boolean
    var
        HttpClient: HttpClient;
        HttpRequest: HttpRequestMessage;
        HttpContent: HttpContent;
        HttpResponse: HttpResponseMessage;
        Headers: HttpHeaders;
        ContentHeaders: HttpHeaders;
    begin
        ValidateSetup(AISetup);

        HttpContent.WriteFrom(RequestBody);
        HttpContent.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        HttpClient.Timeout(AISetup."Coding Request Timeout (ms)");

        HttpRequest.Method := 'POST';
        HttpRequest.SetRequestUri(AISetup."Coding API Base URL" + '/chat/completions');
        HttpRequest.Content(HttpContent);
        HttpRequest.GetHeaders(Headers);
        Headers.Add('Authorization', StrSubstNo('Bearer %1', AISetup."Coding API Key"));

        if not HttpClient.Send(HttpRequest, HttpResponse) then
            exit(false);

        if not HttpResponse.IsSuccessStatusCode() then begin
            HttpResponse.Content().ReadAs(ResponseText);
            Error(HttpRequestFailedErr, HttpResponse.HttpStatusCode(), ResponseText);
        end;

        HttpResponse.Content().ReadAs(ResponseText);
        exit(true);
    end;

    local procedure ValidateSetup(AISetup: Record "PaperTide AI Setup")
    begin
        if AISetup."Coding API Base URL" = '' then
            Error(SetupNotConfiguredErr);
        if AISetup."Coding API Key" = '' then
            Error(SetupNotConfiguredErr);
        if AISetup."Coding Model Name" = '' then
            Error(SetupNotConfiguredErr);
    end;

    local procedure ParseResponse(ResponseText: Text; var PredictionsArr: JsonArray): Boolean
    var
        ResponseJson: JsonObject;
        ChoicesArr: JsonArray;
        ChoiceObj: JsonObject;
        MessageObj: JsonObject;
        ContentToken: JsonToken;
        ContentText: Text;
    begin
        if not ResponseJson.ReadFrom(ResponseText) then
            exit(false);

        if not ResponseJson.Get('choices', ContentToken) then
            exit(false);

        ChoicesArr := ContentToken.AsArray();
        if ChoicesArr.Count() = 0 then
            exit(false);

        ChoicesArr.Get(0, ContentToken);
        ChoiceObj := ContentToken.AsObject();

        if not ChoiceObj.Get('message', ContentToken) then
            exit(false);

        MessageObj := ContentToken.AsObject();

        if not MessageObj.Get('content', ContentToken) then
            exit(false);

        ContentText := ContentToken.AsValue().AsText();
        ContentText := CleanJsonResponse(ContentText);

        if not PredictionsArr.ReadFrom(ContentText) then
            exit(false);

        exit(true);
    end;

    local procedure CleanJsonResponse(ResponseText: Text) CleanText: Text
    begin
        CleanText := ResponseText;

        if CopyStr(CleanText, 1, 7).ToLower() = '```json' then
            CleanText := CleanText.Substring(8)
        else if CleanText.StartsWith('```') then
            CleanText := CleanText.Substring(4);
        if CleanText.EndsWith('```') then
            CleanText := CleanText.Substring(1, StrLen(CleanText) - 3);

        CleanText := CleanText.Trim();
    end;

    local procedure ApplyPredictions(EntryNo: Integer; PredictionsArr: JsonArray)
    var
        ImportDocLine: Record "PaperTide Import Doc. Line";
        PredictionToken: JsonToken;
        PredictionObj: JsonObject;
        LineNo: Integer;
        GLAccountNo: Code[20];
        Confidence: Text[10];
        Reason: Text[250];
        i: Integer;
    begin
        for i := 0 to PredictionsArr.Count() - 1 do begin
            PredictionsArr.Get(i, PredictionToken);
            PredictionObj := PredictionToken.AsObject();

            LineNo := GetJsonIntValue(PredictionObj, 'LineNo');
            GLAccountNo := CopyStr(GetJsonTextValue(PredictionObj, 'GLAccountNo'), 1, 20);
            Confidence := CopyStr(GetJsonTextValue(PredictionObj, 'Confidence'), 1, 10);
            Reason := CopyStr(GetJsonTextValue(PredictionObj, 'Reason'), 1, 250);

            if ImportDocLine.Get(EntryNo, LineNo) then begin
                // Validate GL account before applying
                if (GLAccountNo <> '') and ValidateGLAccount(GLAccountNo) then
                    ImportDocLine."No." := GLAccountNo;

                ImportDocLine."GL Suggestion Confidence" := Confidence;
                ImportDocLine."GL Suggestion Reason" := Reason;
                ImportDocLine.Modify();
            end;
        end;
    end;

    local procedure ValidateGLAccount(AccountNo: Code[20]): Boolean
    var
        GLAccount: Record "G/L Account";
    begin
        if not GLAccount.Get(AccountNo) then
            exit(false);
        if GLAccount."Account Type" <> GLAccount."Account Type"::Posting then
            exit(false);
        if GLAccount.Blocked then
            exit(false);
        exit(true);
    end;

    local procedure GetJsonTextValue(JsonObj: JsonObject; FieldName: Text): Text
    var
        JsonToken: JsonToken;
    begin
        if not JsonObj.Get(FieldName, JsonToken) then
            exit('');
        if JsonToken.AsValue().IsNull() then
            exit('');
        exit(JsonToken.AsValue().AsText());
    end;

    local procedure GetJsonIntValue(JsonObj: JsonObject; FieldName: Text): Integer
    var
        JsonToken: JsonToken;
        ValueText: Text;
        Result: Integer;
    begin
        if not JsonObj.Get(FieldName, JsonToken) then
            exit(0);
        if JsonToken.AsValue().IsNull() then
            exit(0);
        ValueText := JsonToken.AsValue().AsText();
        if Evaluate(Result, ValueText) then
            exit(Result);
        exit(0);
    end;
}
