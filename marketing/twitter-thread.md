# Twitter/X Thread

## Tweet 1 (hook):
OpenAI won't let you export your ChatGPT Team/Business workspace conversations.

No export button. No API. Nothing.

And if your subscription expires? Everything gets deleted in 30 days.

So I built a tool that exports all your conversations in 15 minutes. Free. 🧵

## Tweet 2:
The problem:
- Personal ChatGPT accounts have an "Export data" button in Settings
- Team/Business workspace accounts? Nothing
- OpenAI has known since 2024. Still no fix.
- This arguably violates GDPR Article 20 (data portability)

## Tweet 3:
What my tool does:
- Exports ALL conversations (personal or workspace)
- Downloads file attachments (images, PDFs, docs)
- Handles rate limiting automatically
- One-click Chrome extension or paste-and-go script
- Your data never leaves your machine

## Tweet 4:
I just exported 783 conversations + 570 attachments from my workspace.

The output is a clean JSON file with the full conversation tree — every message, every response, every file reference.

~15 minutes. Zero manual clicking.

## Tweet 5:
How it works:
- Uses the same internal APIs that chatgpt.com uses
- Your existing browser session handles auth
- No API keys needed
- Paginates through all conversations
- Retries automatically if rate limited

## Tweet 6:
The console script is free and open source (MIT).

Chrome extension with a nice UI coming to the Chrome Web Store.

GitHub: github.com/hoya98/chatgpt-export

Your data. Your right to export it.

## Tweet 7 (CTA):
If you're on a ChatGPT Team/Business plan, bookmark this.

You'll need it when:
- You want to switch to Claude or another AI
- Your subscription expires
- You need to audit your team's conversations
- You just want a backup of your own work

⭐ github.com/hoya98/chatgpt-export

---

# Hacker News Post

## Title:
Show HN: Export all ChatGPT conversations (including Team/Business workspaces)

## URL:
https://github.com/hoya98/chatgpt-export

## Text (if self-post):
ChatGPT's Team/Business workspace accounts have no data export option. Personal accounts get an "Export data" button in Settings, but workspace users get nothing. Your conversations are deleted 30 days after subscription expires.

I built a tool that uses ChatGPT's internal backend-api to paginate through all conversations and export them as JSON. It handles workspace auth (via the _account cookie), rate limiting with exponential backoff, and optionally downloads file attachments.

Two flavors:
- Browser console script (MIT, copy-paste-run)
- Chrome extension with progress UI (source-available)

Tested on a workspace with 783 conversations — exported everything including 570 attachments in about 15 minutes.

Technical details in the README. Feedback welcome.
