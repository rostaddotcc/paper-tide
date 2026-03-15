table 50100 "PaperTide AI Setup"
{
    Caption = 'PaperTide AI Setup';
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
            ToolTip = 'Specifies the base URL for the AI API (e.g., https://api.openai.com/v1). Use Provider Presets for quick setup.';
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
            ToolTip = 'Specifies the AI model name (e.g., gpt-4o, gpt-4-vision-preview). Use Provider Presets for quick setup.';
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
        field(110; "Enable Auto Coding"; Boolean)
        {
            Caption = 'Enable Auto Coding';
            DataClassification = CustomerContent;
            ToolTip = 'When enabled, a separate text AI model classifies invoice lines against the chart of accounts after extraction';
            InitValue = false;
        }
        field(111; "Coding API Base URL"; Text[250])
        {
            Caption = 'Coding API Base URL';
            DataClassification = CustomerContent;
            ToolTip = 'Base URL for the coding/classification AI API (e.g., https://api.openai.com/v1)';
        }
        field(112; "Coding API Key"; Text[250])
        {
            Caption = 'Coding API Key';
            DataClassification = CustomerContent;
            ToolTip = 'API key for the coding/classification AI service';
            ExtendedDatatype = Masked;
        }
        field(113; "Coding Model Name"; Text[50])
        {
            Caption = 'Coding Model Name';
            DataClassification = CustomerContent;
            ToolTip = 'Model name for GL account classification (e.g., qwen3-32b, gpt-4o-mini)';
        }
        field(114; "Coding Max Tokens"; Integer)
        {
            Caption = 'Coding Max Tokens';
            DataClassification = CustomerContent;
            ToolTip = 'Maximum tokens for the coding AI response';
            InitValue = 1024;
            MinValue = 100;
            MaxValue = 4096;
        }
        field(115; "Coding Temperature"; Decimal)
        {
            Caption = 'Coding Temperature';
            DataClassification = CustomerContent;
            ToolTip = 'Temperature for coding AI (0.0 = deterministic)';
            InitValue = 0.0;
            MinValue = 0.0;
            MaxValue = 2.0;
            DecimalPlaces = 0 : 2;
        }
        field(116; "Coding Request Timeout (ms)"; Integer)
        {
            Caption = 'Coding Request Timeout (ms)';
            DataClassification = CustomerContent;
            ToolTip = 'Timeout in milliseconds for coding API requests';
            InitValue = 30000;
            MinValue = 5000;
            MaxValue = 120000;
        }
        field(117; "Coding System Prompt"; Blob)
        {
            Caption = 'Coding System Prompt';
            DataClassification = CustomerContent;
            ToolTip = 'System prompt for the GL account classification AI';
        }
        field(118; "Chart Context Max Accounts"; Integer)
        {
            Caption = 'Chart Context Max Accounts';
            DataClassification = CustomerContent;
            ToolTip = 'Maximum number of G/L accounts to include in the coding AI context';
            InitValue = 200;
            MinValue = 10;
            MaxValue = 1000;
        }
        field(119; "Coding History Invoices"; Integer)
        {
            Caption = 'Coding History Invoices';
            DataClassification = CustomerContent;
            ToolTip = 'Number of recent posted invoices per vendor to include as historical context (0 = no history)';
            InitValue = 10;
            MinValue = 0;
            MaxValue = 50;
        }
        field(120; "Coding History Days"; Integer)
        {
            Caption = 'Coding History Days';
            DataClassification = CustomerContent;
            ToolTip = 'Only include posted invoices from the last N days as historical context (0 = no date limit)';
            InitValue = 0;
            MinValue = 0;
            MaxValue = 3650;
        }
        field(121; "Processing Timeout (min)"; Integer)
        {
            Caption = 'Processing Timeout (min)';
            DataClassification = CustomerContent;
            ToolTip = 'Documents stuck in Processing status longer than this will be automatically reset to Error. Set to 0 to disable timeout detection.';
            InitValue = 5;
            MinValue = 0;
            MaxValue = 60;
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

        // If Auto Coding is enabled, skip chart of accounts in vision prompt (text model handles it separately)
        if "Enable Auto Coding" then
            exit(PromptText);

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
        if "Enable Auto Coding" then
            Context := BuildChartOfAccountsContextV2()
        else
            Context := BuildChartOfAccountsContext();
        Clear("Chart of Accounts Context");
        if Context <> '' then begin
            "Chart of Accounts Context".CreateOutStream(OutStream, TextEncoding::UTF8);
            OutStream.WriteText(Context);
        end;
        Modify();
    end;

    procedure BuildChartOfAccountsContextV2(): Text
    var
        GLAccount: Record "G/L Account";
        Context: Text;
        LineCount: Integer;
        MaxAccounts: Integer;
    begin
        Context := '';
        LineCount := 0;
        MaxAccounts := "Chart Context Max Accounts";
        if MaxAccounts <= 0 then
            MaxAccounts := 200;

        GLAccount.SetRange("Account Type", GLAccount."Account Type"::Posting);
        GLAccount.SetRange(Blocked, false);

        if GLAccount.FindSet() then begin
            repeat
                if Context <> '' then
                    Context += '\n';
                Context += '- ' + GLAccount."No." + ': ' + GLAccount.Name;
                if Format(GLAccount."Account Category") <> '' then
                    Context += ' (Category: ' + Format(GLAccount."Account Category") + ')';
                if GLAccount."Account Subcategory Descript." <> '' then
                    Context += ' [' + GLAccount."Account Subcategory Descript." + ']';
                LineCount += 1;

                if LineCount >= MaxAccounts then
                    break;
            until GLAccount.Next() = 0;
        end;

        exit(Context);
    end;

    procedure GetCodingSystemPrompt(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
        PromptText: Text;
    begin
        CalcFields("Coding System Prompt");
        if "Coding System Prompt".HasValue() then begin
            "Coding System Prompt".CreateInStream(InStream, TextEncoding::UTF8);
            PromptText := TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator());
            exit(PromptText);
        end;
        exit(GetDefaultCodingSystemPrompt());
    end;

    procedure SetCodingSystemPrompt(PromptText: Text)
    var
        OutStream: OutStream;
    begin
        Clear("Coding System Prompt");
        if PromptText <> '' then begin
            "Coding System Prompt".CreateOutStream(OutStream, TextEncoding::UTF8);
            OutStream.WriteText(PromptText);
        end;
    end;

    procedure GetDefaultCodingSystemPrompt(): Text
    begin
        exit(
            'You are an expert accounting classification system. Assign the most appropriate ' +
            'G/L account number to each invoice line based on its description.\n\n' +
            'Rules:\n' +
            '1. Only use account numbers from the provided chart of accounts.\n' +
            '2. Consider the line description, amount, vendor context, and posting history.\n' +
            '3. If posting history is provided, strongly prefer the same accounts and dimensions ' +
            'used for similar line descriptions from the same vendor.\n' +
            '4. Return ONLY valid JSON array, one object per line, same order as input.\n' +
            '5. Each object: {"LineNo": 10000, "GLAccountNo": "6110", "Confidence": "High", "Reason": "..."}\n' +
            '6. Confidence levels: "High" = strong match from history or obvious category, ' +
            '"Medium" = reasonable match, "Low" = uncertain.\n' +
            '7. If unsure, return empty GLAccountNo with Confidence "Low".'
        );
    end;

    procedure GetOrCreateSetup(): Record "PaperTide AI Setup"
    begin
        if not Get() then begin
            Init();
            "Primary Key" := '';
            "Max Tokens" := 2048;
            Temperature := 0.1;
            "Request Timeout (ms)" := 60000;
            "Max Concurrency" := 3;
            "Processing Timeout (min)" := 5;
            Insert();
        end;
        exit(Rec);
    end;
}
