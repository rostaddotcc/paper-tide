page 50100 "AI Extraction Setup"
{
    Caption = 'AI Extraction Setup';
    PageType = Card;
    SourceTable = "AI Extraction Setup";
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
                    ToolTip = 'Specifies the base URL for the AI API (e.g., https://dashscope.aliyuncs.com/compatible-mode/v1 for Qwen-VL, https://api.openai.com/v1 for OpenAI)';
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
                    ToolTip = 'Specifies the model name (e.g., qwen-vl-max, gpt-4-vision-preview, gpt-4o)';
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
            }

            group(Defaults)
            {
                Caption = 'Default Values';

                field("Default G/L Account"; Rec."Default G/L Account")
                {
                    ApplicationArea = All;
                    ToolTip = 'Default G/L account for invoice lines';
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

            group(FutureFeatures)
            {
                Caption = 'Future Features (Reserved)';
                Visible = false; // Hidden until PDF conversion is implemented

                field("Enable PDF Conversion"; Rec."Enable PDF Conversion")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable PDF conversion (reserved for v2.0)';
                    Enabled = false;
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
                    QwenVLAPI: Codeunit "Qwen VL API";
                begin
                    if QwenVLAPI.TestConnection() then
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
        }
        area(Creation)
        {
            group(ProviderPresets)
            {
                Caption = 'Provider Presets';
                ToolTip = 'Quick setup for popular AI providers';
                Image = Setup;

                action(SetQwenVL)
                {
                    ApplicationArea = All;
                    Caption = 'Use Qwen-VL (Alibaba)';
                    ToolTip = 'Configure for Qwen-VL vision model from Alibaba Cloud';
                    Image = Action;

                    trigger OnAction()
                    begin
                        if Confirm('Set up for Qwen-VL? This will update the API Base URL and Model Name.', false) then begin
                            Rec."API Base URL" := 'https://dashscope.aliyuncs.com/compatible-mode/v1';
                            Rec."Model Name" := 'qwen-vl-max';
                            Rec.Modify();
                            Message('Qwen-VL preset applied. Please enter your API Key from Alibaba Cloud DashScope.');
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
