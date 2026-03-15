table 50100 "AI Extraction Setup"
{
    Caption = 'AI Extraction Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(2; "API Base URL"; Text[250])
        {
            Caption = 'API Base URL';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the base URL for the AI API (e.g., https://dashscope.aliyuncs.com/compatible-mode/v1 for Qwen-VL, https://api.openai.com/v1 for OpenAI)';
        }
        field(3; "API Key"; Text[250])
        {
            Caption = 'API Key';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the API key for authenticating with the AI service';
            ExtendedDatatype = Masked;
        }
        field(4; "Model Name"; Text[50])
        {
            Caption = 'Model Name';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the model name (e.g., qwen-vl-max, gpt-4-vision-preview, gpt-4o)';
        }
        field(5; "Max Tokens"; Integer)
        {
            Caption = 'Max Tokens';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the maximum number of tokens for the AI response';
            InitValue = 2048;
            MinValue = 100;
            MaxValue = 4096;
        }
        field(6; Temperature; Decimal)
        {
            Caption = 'Temperature';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the temperature for AI response (0.0 = deterministic, 1.0 = creative)';
            InitValue = 0.1;
            MinValue = 0.0;
            MaxValue = 2.0;
            DecimalPlaces = 0 : 2;
        }
        field(7; "System Prompt"; Blob)
        {
            Caption = 'System Prompt';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the system prompt that instructs the AI how to extract and format invoice data';
        }
        field(8; "Request Timeout (ms)"; Integer)
        {
            Caption = 'Request Timeout (ms)';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the timeout in milliseconds for API requests';
            InitValue = 60000;
            MinValue = 10000;
            MaxValue = 300000;
        }
        field(9; "Default G/L Account"; Code[20])
        {
            Caption = 'Default G/L Account';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the default G/L account to use for invoice lines when no specific account can be determined';
            TableRelation = "G/L Account" where("Account Type" = const(Posting), Blocked = const(false));
        }
        field(10; "Enable AI GL Suggestion"; Boolean)
        {
            Caption = 'Enable AI GL Suggestion';
            DataClassification = CustomerContent;
            ToolTip = 'When enabled, the AI will analyze the chart of accounts and suggest the most appropriate G/L account for each invoice line based on the description';
            InitValue = false;
        }
        field(12; "Max Concurrency"; Integer)
        {
            Caption = 'Max Concurrency';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the maximum number of documents that can be processed simultaneously';
            InitValue = 3;
            MinValue = 1;
            MaxValue = 10;
        }
        field(11; "Chart of Accounts Context"; Blob)
        {
            Caption = 'Chart of Accounts Context';
            DataClassification = CustomerContent;
            ToolTip = 'Cached chart of accounts sent to AI for GL account suggestions';
        }
        field(20; "Enable PDF Conversion"; Boolean)
        {
            Caption = 'Enable PDF Conversion';
            DataClassification = CustomerContent;
            ToolTip = 'When enabled, PDF files can be uploaded and are automatically converted to images via Gotenberg before AI extraction';
        }
        field(21; "PDF Converter Endpoint"; Text[250])
        {
            Caption = 'PDF Converter Endpoint';
            DataClassification = CustomerContent;
            ToolTip = 'Base URL for the Gotenberg PDF conversion service (e.g., https://pdf.example.com)';
        }
        field(22; "PDF Converter API Key"; Text[250])
        {
            Caption = 'PDF Converter API Key';
            DataClassification = CustomerContent;
            ToolTip = 'Optional API key if the PDF conversion service requires authentication';
            ExtendedDatatype = Masked;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }



    procedure GetSystemPrompt(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
        PromptText: Text;
    begin
        CalcFields("System Prompt");
        if "System Prompt".HasValue() then begin
            "System Prompt".CreateInStream(InStream, TextEncoding::UTF8);
            PromptText := TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator());
            exit(PromptText);
        end;
        exit(GetDefaultSystemPrompt());
    end;

    procedure SetSystemPrompt(PromptText: Text)
    var
        OutStream: OutStream;
    begin
        Clear("System Prompt");
        if PromptText <> '' then begin
            "System Prompt".CreateOutStream(OutStream, TextEncoding::UTF8);
            OutStream.WriteText(PromptText);
        end;
    end;

    procedure GetDefaultSystemPrompt(): Text
    begin
        exit(
            'You are an expert invoice data extraction system. Analyze the provided invoice image and extract all relevant information. ' +
            'Return ONLY a valid JSON object with the following structure (no markdown, no explanation, just raw JSON):\n' +
            '{\n' +
            '  "VendorNo": "",\n' +
            '  "VendorName": "",\n' +
            '  "VendorVATNo": "",\n' +
            '  "VendorBankAccount": "",\n' +
            '  "InvoiceNo": "",\n' +
            '  "InvoiceDate": "YYYY-MM-DD",\n' +
            '  "DueDate": "YYYY-MM-DD",\n' +
            '  "AmountInclVAT": 0.00,\n' +
            '  "AmountExclVAT": 0.00,\n' +
            '  "VATAmount": 0.00,\n' +
            '  "CurrencyCode": "",\n' +
            '  "PONumber": "",\n' +
            '  "Lines": [\n' +
            '    {\n' +
            '      "Description": "",\n' +
            '      "Quantity": 0,\n' +
            '      "UnitPrice": 0.00,\n' +
            '      "Amount": 0.00,\n' +
            '      "GLAccountNo": ""\n' +
            '    }\n' +
            '  ]\n' +
            '}\n' +
            'Use null for values you cannot extract. Use 0 for missing numeric values. Use ISO 8601 date format.'
        );
    end;

    procedure GetSystemPromptWithChartOfAccounts(): Text
    var
        PromptText: Text;
        ChartOfAccountsContext: Text;
    begin
        PromptText := GetSystemPrompt();

        if not "Enable AI GL Suggestion" then
            exit(PromptText);

        // Read from cache instead of database for better performance
        ChartOfAccountsContext := GetChartOfAccountsContext();

        if ChartOfAccountsContext = '' then
            exit(PromptText);

        PromptText += '\n\nADDITIONAL INSTRUCTION FOR G/L ACCOUNT SUGGESTION:\n';
        PromptText += 'Based on the invoice line descriptions and the following chart of accounts, ';
        PromptText += 'suggest the most appropriate G/L Account No. for each line in the "GLAccountNo" field.\n\n';
        PromptText += 'Available G/L Accounts:\n';
        PromptText += ChartOfAccountsContext;
        PromptText += '\n\nIf no suitable account can be determined, leave GLAccountNo empty.';

        exit(PromptText);
    end;

    local procedure BuildChartOfAccountsContext(): Text
    var
        GLAccount: Record "G/L Account";
        Context: Text;
        LineCount: Integer;
    begin
        Context := '';
        LineCount := 0;

        GLAccount.SetRange("Account Type", GLAccount."Account Type"::Posting);
        GLAccount.SetRange(Blocked, false);

        if GLAccount.FindSet() then begin
            repeat
                if Context <> '' then
                    Context += '\n';
                Context += '- ' + GLAccount."No." + ': ' + GLAccount.Name;
                LineCount += 1;

                // Limit to avoid token overflow
                if LineCount >= 100 then
                    break;
            until GLAccount.Next() = 0;
        end;

        exit(Context);
    end;

    procedure GetChartOfAccountsContext(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
        Context: Text;
    begin
        CalcFields("Chart of Accounts Context");
        if "Chart of Accounts Context".HasValue() then begin
            "Chart of Accounts Context".CreateInStream(InStream, TextEncoding::UTF8);
            Context := TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator());
            exit(Context);
        end;
        // Fallback: build from database if cache is empty
        exit(BuildChartOfAccountsContext());
    end;

    procedure RefreshChartOfAccountsContext()
    var
        OutStream: OutStream;
        Context: Text;
    begin
        Context := BuildChartOfAccountsContext();
        Clear("Chart of Accounts Context");
        if Context <> '' then begin
            "Chart of Accounts Context".CreateOutStream(OutStream, TextEncoding::UTF8);
            OutStream.WriteText(Context);
        end;
        Modify();
    end;

    procedure GetOrCreateSetup(): Record "AI Extraction Setup"
    begin
        if not Get() then begin
            Init();
            "Primary Key" := '';
            "Max Tokens" := 2048;
            Temperature := 0.1;
            "Request Timeout (ms)" := 60000;
            "Max Concurrency" := 3;
            Insert();
        end;
        exit(Rec);
    end;
}
