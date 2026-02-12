# ChatGPT Export

**Bulk export all your ChatGPT conversations** -- including Team and Business workspaces where OpenAI doesn't provide a native export.

OpenAI lets personal account users export their data, but **Team/Business workspace users have no export option**. This tool fixes that.

## What it does

- Exports **all conversations** from your ChatGPT account (personal or workspace)
- Includes **archived conversations**
- Finds and optionally downloads **file attachments** (images, PDFs, etc.)
- Handles **rate limiting** with automatic retry and exponential backoff
- Outputs a single JSON file with your complete conversation history

## Quick Start (Browser Console)

The fastest way -- no installation needed:

1. Go to [chatgpt.com](https://chatgpt.com) and log in
2. If you're on a workspace, make sure you've switched to it
3. Open browser DevTools (F12 or Cmd+Option+I)
4. Go to the **Console** tab
5. Copy and paste the contents of [`scripts/export.js`](scripts/export.js)
6. Press Enter and wait

Your conversations will download as a JSON file when complete.

## Chrome Extension

For a better experience with a progress bar and options:

1. Download or clone this repo
2. Open Chrome and go to `chrome://extensions/`
3. Enable **Developer mode** (top right toggle)
4. Click **Load unpacked** and select the `extension/` folder
5. Go to [chatgpt.com](https://chatgpt.com) and log in
6. Click the extension icon and hit **Export All Conversations**

## How it works

ChatGPT's web app uses internal API endpoints (`/backend-api/`) that are accessible from your browser session. This tool:

1. Gets your session token from `/api/auth/session`
2. Detects workspace accounts via the `_account` cookie
3. Paginates through all conversations via `/backend-api/conversations`
4. Fetches full content of each conversation via `/backend-api/conversation/{id}`
5. Extracts file attachment references from conversation data
6. Packages everything into a downloadable JSON file

No API keys needed -- it uses your existing browser session.

## Output format

```json
{
  "export_time": "2026-02-10T00:00:00.000Z",
  "workspace_account_id": "uuid-or-null",
  "conversation_count": 783,
  "attachment_count": 1012,
  "errors": [],
  "attachments": {
    "file-id": { "name": "document.pdf", "conversationId": "conv-id" }
  },
  "conversations": [
    {
      "id": "conversation-uuid",
      "title": "My Conversation",
      "create_time": 1700000000.0,
      "update_time": 1700000500.0,
      "conversation": {
        "title": "My Conversation",
        "mapping": {
          "message-uuid": {
            "message": {
              "author": { "role": "user" },
              "content": { "content_type": "text", "parts": ["Hello!"] }
            }
          }
        }
      }
    }
  ]
}
```

## FAQ

**Why can't I just use Settings > Data Controls > Export?**
That option only exists for personal accounts. Team/Business workspace accounts don't have it. OpenAI has acknowledged this but hasn't fixed it since 2024.

**Is this against OpenAI's terms?**
This tool accesses your own data through the same APIs that the ChatGPT web interface uses. You have a right to your own data under GDPR Article 20 (data portability).

**How long does it take?**
About 1 conversation per second. A workspace with 800 conversations takes ~15 minutes.

**What about rate limits?**
The tool automatically handles rate limiting with exponential backoff. If you get rate limited, it waits and retries.

**Some attachments fail to download?**
Older file attachments expire from OpenAI's servers (usually after a few months). These return HTTP 422 errors. Recent files should download fine.

## License

MIT -- do whatever you want with it.
