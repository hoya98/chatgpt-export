# Reddit Post (for r/ChatGPT and r/OpenAI)

## Title:
I built a free tool to export all your ChatGPT conversations — including Team/Business workspaces where OpenAI gives you NO export option

## Body:

If you're on a ChatGPT Team (now Business) plan, you've probably noticed there's no "Export data" button in Settings. That feature only exists for personal accounts.

This means:
- You can't back up your workspace conversations
- If your subscription expires, everything gets **deleted after 30 days**
- OpenAI has known about this since 2024 and hasn't fixed it
- This arguably violates GDPR Article 20 (right to data portability)

So I built a tool that does it.

**What it does:**
- Exports ALL your conversations (personal or workspace) as a JSON file
- Finds and downloads file attachments (images, PDFs, etc.)
- Handles rate limiting automatically
- Works with Personal, Team, and Business accounts
- One click in the Chrome extension, or paste a script in your browser console

**How it works:**
It uses the same internal APIs that the ChatGPT web interface uses. No API keys needed — just your existing browser session. Your data never leaves your machine.

I just exported 783 conversations from my workspace in about 15 minutes.

**Links:**
- GitHub (free, open source): https://github.com/hoya98/chatgpt-export
- Chrome Extension: [link when published]

MIT licensed. Do whatever you want with it.

---

*Crosspost to: r/ChatGPT, r/OpenAI, r/DataHoarder, r/selfhosted*

---

# Reddit Post (for r/DataHoarder)

## Title:
Tool to bulk export all ChatGPT conversations (including Team/Business workspaces that have no native export)

## Body:

ChatGPT Team/Business accounts have no data export option. Your conversations get deleted 30 days after subscription ends.

Built an open-source tool that exports everything via the internal API:
- 783 conversations + 570 file attachments in ~15 minutes
- Chrome extension or browser console script
- Outputs clean JSON with full conversation trees
- MIT licensed

GitHub: https://github.com/hoya98/chatgpt-export
