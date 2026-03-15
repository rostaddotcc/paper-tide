---
name: Import Methods and PDF Conversion
description: Planned import sources (Azure Blob, SFTP, email) and PDF conversion strategy using Gotenberg container
type: project
---

## Importmetoder

Planerade importmetoder utöver dagens manuella uppladdning:

1. **Manuell uppladdning** — fungerar idag (Batch Upload page)
2. **Azure Blob Storage** — hämta fakturor (PDF/bilder) från en Azure storage container
3. **SFTP** — hämta fakturor från SFTP-server (via Azure Function som brygga till Blob Storage)
4. **E-postinkorg** — fetcha PDF:er från e-post via Microsoft Graph API (behöver utredas)

**Why:** Automatisera inflödet av fakturor istället för manuell uppladdning.
**How to apply:** Varje importmetod ska mata in dokument i samma Import Document Header-kö som dagens uppladdning.

## PDF-konvertering (Gotenberg)

Beslutad approach: **Gotenberg** (Docker-container, Apache 2.0) som lokal/molnbaserad PDF-konverteringstjänst.

**Två riktningar:**
- **PDF → bild(er):** Vid uppladdning av PDF, konvertera till bilder för AI-extraktion. Flersidiga PDF:er skickas som flera bilder i ett multimodalt AI-anrop (ej separata Import Documents).
- **Bild → PDF:** Vid skapande av inköpsfaktura, konvertera originalbilden till PDF för attachment. Slutresultatet ska ALLTID vara en PDF-attachment på Purchase Invoice, oavsett originalformat.

**Hosting-alternativ:**
- Lokalt: `docker run -p 3000:3000 gotenberg/gotenberg:8`
- Azure: Container Apps (kan skala till 0) eller ACI. Säkra med VNet eller API Management.

**Gotenberg endpoints:**
- PDF→bild: `POST /forms/pdfengines/convert`
- Bild→PDF: `POST /forms/libreoffice/convert`

**BC-integration:**
- Setup-fälten 20-22 (PDF Converter Endpoint, API Key) redan förberedda
- Ny Codeunit 50104 "PDF Converter" med ConvertPdfToImage och ConvertImageToPdf
- AttachInvoiceImageToPurchaseInvoice ändras att alltid bifoga PDF
- BC:s standard Document Attachment FactBox visar PDF med zoom, bläddring etc.

**Status:** Ej implementerat — användaren behöver sätta upp Gotenberg lokalt först innan kodning påbörjas.
