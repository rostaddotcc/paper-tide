page 50100 "PaperTide AI Setup"
{
    Caption = 'PaperTide AI Setup';
    PageType = Card;
    SourceTable = "PaperTide AI Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'Connection Settings';

                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the base URL for the AI API (e.g., https://api.openai.com/v1). Use Provider Presets for quick setup.';
                }
                field("API Key"; Rec."API Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the API key for authenticating with the AI service';
                    ExtendedDatatype = Masked;
                }
                field("Model Name"; Rec."Model Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the AI model name (e.g., gpt-4o, gpt-4-vision-preview). Use Provider Presets for quick setup.';
                }
            }

            group(Parameters)
            {
                Caption = 'AI Parameters';

                field("Max Tokens"; Rec."Max Tokens")
                {
                    ApplicationArea = All;
                    ToolTip = 'Maximum tokens for AI response';
                }
                field(Temperature; Rec.Temperature)
                {
                    ApplicationArea = All;
                    ToolTip = 'Temperature for AI creativity (0.0-1.0 recommended)';
                }
                field("Request Timeout (ms)"; Rec."Request Timeout (ms)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Timeout for API requests in milliseconds';
                }
                field("Max Concurrency"; Rec."Max Concurrency")
                {
                    ApplicationArea = All;
                    ToolTip = 'Maximum number of documents processed simultaneously';
                }
                field("Processing Timeout (min)"; Rec."Processing Timeout (min)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Documents stuck in Processing longer than this are automatically reset to Error. Set to 0 to disable.';
                }
            }

            group(Defaults)
            {
                Caption = 'Default Values';

                field("Default G/L Account"; Rec."Default G/L Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Default G/L account for invoice lines';
                }
                field("Enable AI GL Suggestion"; Rec."Enable AI GL Suggestion")
                {
                    ApplicationArea = All;
                    ToolTip = 'When enabled, AI will analyze the chart of accounts and suggest the most appropriate G/L account for each invoice line';
                }
            }

            group(AutoCoding)
            {
                Caption = 'Auto Coding';

                field("Enable Auto Coding"; Rec."Enable Auto Coding")
                {
                    ApplicationArea = All;
                    ToolTip = 'When enabled, a separate text AI model classifies invoice lines against the chart of accounts after extraction';
                }
                group(CodingModelConnection)
                {
                    Caption = 'Coding Model Connection';
                    Visible = Rec."Enable Auto Coding";

                    field("Coding API Base URL"; Rec."Coding API Base URL")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Base URL for the coding/classification AI API';
                    }
                    field("Coding API Key"; Rec."Coding API Key")
                    {
                        ApplicationArea = All;
                        ToolTip = 'API key for the coding/classification AI service';
                        ExtendedDatatype = Masked;
                    }
                    field("Coding Model Name"; Rec."Coding Model Name")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Model name for GL account classification';
                    }
                }
                group(CodingParameters)
                {
                    Caption = 'Coding Parameters';
                    Visible = Rec."Enable Auto Coding";

                    field("Coding Max Tokens"; Rec."Coding Max Tokens")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Maximum tokens for coding AI response';
                    }
                    field("Coding Temperature"; Rec."Coding Temperature")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Temperature for coding AI (0.0 = deterministic)';
                    }
                    field("Coding Request Timeout (ms)"; Rec."Coding Request Timeout (ms)")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Timeout for coding API requests in milliseconds';
                    }
                    field("Chart Context Max Accounts"; Rec."Chart Context Max Accounts")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Maximum number of G/L accounts to include in coding AI context';
                    }
                    field("Coding History Invoices"; Rec."Coding History Invoices")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Number of recent posted invoices per vendor to include as historical context (0 = no history)';
                    }
                    field("Coding History Days"; Rec."Coding History Days")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Only include posted invoices from the last N days (0 = no date limit)';
                    }
                }
            }

            group(SystemPrompt)
            {
                Caption = 'System Prompt';

                field(SystemPromptControl; SystemPromptText)
                {
                    ApplicationArea = All;
                    Caption = 'System Prompt';
                    ToolTip = 'Instructions for the AI on how to extract and format invoice data';
                    MultiLine = true;
                    ShowCaption = false;
                    ExtendedDatatype = RichContent;

                    trigger OnValidate()
                    begin
                        Rec.SetSystemPrompt(SystemPromptText);
                    end;
                }
            }

            group(PDFConversion)
            {
                Caption = 'PDF Conversion';

                field("Enable PDF Conversion"; Rec."Enable PDF Conversion")
                {
                    ApplicationArea = All;
                    ToolTip = 'When enabled, PDF files can be uploaded and are automatically converted to images via Gotenberg before AI extraction';
                }
                field("PDF Converter Endpoint"; Rec."PDF Converter Endpoint")
                {
                    ApplicationArea = All;
                    ToolTip = 'Base URL for the Gotenberg PDF conversion service (e.g., https://pdf.example.com)';
                    Enabled = Rec."Enable PDF Conversion";
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Connection';
                ToolTip = 'Test the connection to the AI API';
                Image = TestDatabase;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    AIVisionAPI: Codeunit "PaperTide AI Vision API";
                begin
                    if AIVisionAPI.TestConnection() then
                        Message('Connection successful! API is reachable.')
                    else
                        Message('Connection failed. Please check your settings.');
                end;
            }
            action(ResetToDefaultPrompt)
            {
                ApplicationArea = All;
                Caption = 'Reset to Default Prompt';
                ToolTip = 'Reset system prompt to default values';
                Image = Restore;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    if Confirm('Reset system prompt to default? This will overwrite any custom prompt.', false) then begin
                        SystemPromptText := Rec.GetDefaultSystemPrompt();
                        Rec.SetSystemPrompt(SystemPromptText);
                    end;
                end;
            }
            action(TestPDFConversion)
            {
                ApplicationArea = All;
                Caption = 'Test PDF Conversion';
                ToolTip = 'Test the connection to the Gotenberg PDF conversion service';
                Image = TestFile;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec."Enable PDF Conversion";

                trigger OnAction()
                var
                    PDFConverter: Codeunit "PaperTide PDF Converter";
                begin
                    if PDFConverter.TestConnection() then
                        Message('PDF conversion service is reachable and healthy.')
                    else
                        Message('PDF conversion service is not reachable. Please check the endpoint URL.');
                end;
            }
            action(RefreshChartOfAccounts)
            {
                ApplicationArea = All;
                Caption = 'Refresh Chart of Accounts';
                ToolTip = 'Update the cached chart of accounts for AI GL account suggestions';
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec."Enable AI GL Suggestion" or Rec."Enable Auto Coding";

                trigger OnAction()
                begin
                    Rec.RefreshChartOfAccountsContext();
                    Message('Chart of accounts refreshed successfully. AI will use the updated account list for suggestions.');
                end;
            }
            action(TestCodingConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Coding Connection';
                ToolTip = 'Test the connection to the coding/classification AI API';
                Image = TestDatabase;
                Promoted = true;
                PromotedCategory = Process;
                Enabled = Rec."Enable Auto Coding";

                trigger OnAction()
                var
                    GLAccountPredictor: Codeunit "PaperTide GL Account Predictor";
                begin
                    if GLAccountPredictor.TestCodingConnection() then
                        Message('Coding API connection successful!')
                    else
                        Message('Coding API connection failed. Please check your settings.');
                end;
            }
            action(VendorNameMappings)
            {
                ApplicationArea = All;
                Caption = 'PaperTide Vendor Mappings';
                ToolTip = 'View and manage vendor name alias mappings learned from user corrections';
                Image = Relationship;
                Promoted = true;
                PromotedCategory = Process;
                RunObject = page "PaperTide Vendor Mappings";
            }
        }
        area(Creation)
        {
            group(ProviderPresets)
            {
                Caption = 'Provider Presets';
                ToolTip = 'Quick setup for popular AI providers';
                Image = Setup;

                action(SetDashScope)
                {
                    ApplicationArea = All;
                    Caption = 'Use DashScope (Alibaba)';
                    ToolTip = 'Configure for Alibaba Cloud DashScope API (OpenAI-compatible)';
                    Image = Action;

                    trigger OnAction()
                    begin
                        if Confirm('Set up for DashScope? This will update the API Base URL and Model Name.', false) then begin
                            Rec."API Base URL" := 'https://dashscope.aliyuncs.com/compatible-mode/v1';
                            Rec."Model Name" := 'qwen-vl-max';
                            Rec.Modify();
                            Message('DashScope preset applied. Please enter your API Key from Alibaba Cloud.');
                        end;
                    end;
                }
                action(SetOpenAI)
                {
                    ApplicationArea = All;
                    Caption = 'Use OpenAI';
                    ToolTip = 'Configure for OpenAI GPT-4 Vision';
                    Image = Action;

                    trigger OnAction()
                    begin
                        if Confirm('Set up for OpenAI? This will update the API Base URL and Model Name.', false) then begin
                            Rec."API Base URL" := 'https://api.openai.com/v1';
                            Rec."Model Name" := 'gpt-4-vision-preview';
                            Rec.Modify();
                            Message('OpenAI preset applied. Please enter your API Key from OpenAI.');
                        end;
                    end;
                }
                action(SetOpenAIGPT4o)
                {
                    ApplicationArea = All;
                    Caption = 'Use OpenAI (GPT-4o)';
                    ToolTip = 'Configure for OpenAI GPT-4o (newer multimodal model)';
                    Image = Action;

                    trigger OnAction()
                    begin
                        if Confirm('Set up for OpenAI GPT-4o? This will update the API Base URL and Model Name.', false) then begin
                            Rec."API Base URL" := 'https://api.openai.com/v1';
                            Rec."Model Name" := 'gpt-4o';
                            Rec.Modify();
                            Message('OpenAI GPT-4o preset applied. Please enter your API Key from OpenAI.');
                        end;
                    end;
                }
                action(SetAzureOpenAI)
                {
                    ApplicationArea = All;
                    Caption = 'Use Azure OpenAI';
                    ToolTip = 'Configure for Azure OpenAI Service (you will need to enter your specific endpoint URL)';
                    Image = Action;

                    trigger OnAction()
                    begin
                        if Confirm('Set up for Azure OpenAI? You will need to enter your specific endpoint URL.', false) then begin
                            Rec."API Base URL" := 'https://your-resource.openai.azure.com/openai/deployments/your-deployment';
                            Rec."Model Name" := 'gpt-4-vision';
                            Rec.Modify();
                            Message('Azure OpenAI preset applied. Please update the API Base URL with your specific Azure endpoint and enter your API Key.');
                        end;
                    end;
                }
                action(SetGroq)
                {
                    ApplicationArea = All;
                    Caption = 'Use Groq';
                    ToolTip = 'Configure for Groq API (fast inference for open source models)';
                    Image = Action;

                    trigger OnAction()
                    begin
                        if Confirm('Set up for Groq? This will update the API Base URL and Model Name.', false) then begin
                            Rec."API Base URL" := 'https://api.groq.com/openai/v1';
                            Rec."Model Name" := 'llava-v1.5-7b';
                            Rec.Modify();
                            Message('Groq preset applied. Please enter your API Key from Groq.');
                        end;
                    end;
                }
                action(SetLocalAI)
                {
                    ApplicationArea = All;
                    Caption = 'Use LocalAI (Local)';
                    ToolTip = 'Configure for LocalAI running on your own server';
                    Image = Action;

                    trigger OnAction()
                    begin
                        if Confirm('Set up for LocalAI? This will update the API Base URL.', false) then begin
                            Rec."API Base URL" := 'http://localhost:8080/v1';
                            Rec."Model Name" := 'llava';
                            Rec.Modify();
                            Message('LocalAI preset applied. Make sure your LocalAI server is running and update the URL/port if needed.');
                        end;
                    end;
                }
                action(SetOllama)
                {
                    ApplicationArea = All;
                    Caption = 'Use Ollama (Local)';
                    ToolTip = 'Configure for Ollama running locally';
                    Image = Action;

                    trigger OnAction()
                    begin
                        if Confirm('Set up for Ollama? This will update the API Base URL.', false) then begin
                            Rec."API Base URL" := 'http://localhost:11434/v1';
                            Rec."Model Name" := 'llava';
                            Rec.Modify();
                            Message('Ollama preset applied. Make sure Ollama is running and update the URL/port if needed.');
                        end;
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetOrCreateSetup();
        SystemPromptText := Rec.GetSystemPrompt();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if SystemPromptText <> '' then
            Rec.SetSystemPrompt(SystemPromptText);
        exit(true);
    end;

    var
        SystemPromptText: Text;
}
