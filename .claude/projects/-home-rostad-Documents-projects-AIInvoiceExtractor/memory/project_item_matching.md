---
name: Item Matching Feature
description: Planned feature to match invoice lines against Item master data, with AI suggestion, cross-reference lookup, and price validation
type: project
---

Artikelmatchning planerad som nästa stora feature efter G/L-kontoförslag.

**Design beslutad:**
1. Skicka artikelkatalog (Item-tabell) till AI:n i systemprompt (samma mönster som Chart of Accounts)
2. AI föreslår Type (Item/G/L Account) och ItemNo per rad
3. Matchningskedja: AI-förslag → Item Reference (leverantörens artikelnr) → beskrivningsmatchning → fallback G/L Account
4. Validering: pris mot Last Direct Cost, blockerad-status, enhet
5. Prisvarning i preview om avvikelse överstiger tolerans

**Komponenter att ändra:**
- AI Extraction Setup: `Enable AI Item Suggestion`, `Item Catalog Context` cache
- System Prompt: utöka med artikellista + Type/ItemNo instruktion
- InvoiceExtraction: ny `LookupItemNo()`, utöka `ParseAndSaveToImportDoc`
- Import Document Line: parsning av Type och ItemNo från AI-svar
- Preview Subform: visa Type-kolumn, prisvarning

**Why:** Ger affärsnytta genom automatisk artikelkoppling istället för bara G/L-konton.
**How to apply:** Implementera efter samma mönster som befintliga G/L-kontoförslaget (cache → AI-prompt → validering → fallback).
