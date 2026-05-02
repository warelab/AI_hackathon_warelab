# AI Ready Lab Hackathon Q&A

A lightweight question hub for lab talks and hackathon presentations. Attendees scan a QR code, choose the right session, and submit questions silently during or after the talk. The presenter reviews, filters, answers, and exports questions later.

## Agenda

Monday, May 4, 2026, 1:00 - 4:00 PM.

Session 1 covers getting everyone AI ready, platform options, current tools, and the MCP introduction.

Session 2 covers the Gramene MCP agent lab, hands-on setup, question testing, performance comparison, GSC demo outcomes, MCP extension ideas, and multi-agent setup.

## Run Locally

```bash
npm install
npm run dev
```

Open the presenter dashboard:

```text
http://localhost:5173/
```

Open the audience form directly:

```text
http://localhost:5173/?view=ask&session=session-1
```

The app also prints a network URL in the terminal. Use that URL for audience devices on the same Wi-Fi network.

## GitHub Pages

This repo includes a GitHub Pages workflow at `.github/workflows/deploy-pages.yml`.

GitHub Pages hosts the static interface. Because GitHub Pages cannot run the Express API, hosted responses are saved in each visitor's browser using localStorage. For a shared live room hub, run `npm run dev` on one machine and share the printed network URL or QR code.

## What It Includes

- Two session tabs for separate talk blocks.
- QR code and copyable audience link.
- Anonymous or named question submission.
- Optional response contact field.
- Topic chips for fast triage.
- Presenter inbox with All/New/Answer later/Answered filters.
- Response workspace with private notes and answer drafts.
- CSV export for follow-up.

## Local Data

Questions are saved locally by the Express API under `server/data/questions.json`. That folder is ignored by git so test and event data do not get committed accidentally.
