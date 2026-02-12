# Chrome Web Store Listing

## Name
ChatGPT Export - Bulk Conversation Exporter

## Summary (132 chars max)
Export all your ChatGPT conversations with one click. Works with Team & Business workspaces. Full backup in JSON format.

## Description
**The only way to export conversations from ChatGPT Team & Business workspaces.**

OpenAI lets personal account users export their data, but if you're on a Team or Business plan? No export button. Your conversations are trapped — and they get deleted 30 days after your subscription ends.

ChatGPT Export fixes this.

**Features:**
• Export ALL conversations with one click
• Works with Personal, Team, AND Business workspaces
• Downloads file attachments (images, PDFs, documents)
• Shows real-time progress with conversation count
• Handles rate limiting automatically
• Outputs clean JSON format
• 100% open source — inspect every line of code

**How it works:**
1. Go to chatgpt.com and log in
2. Click the ChatGPT Export icon
3. Hit "Export All Conversations"
4. Wait while it downloads everything
5. Get a complete JSON backup of all your conversations

**Privacy first:**
• Runs entirely in your browser — no data leaves your machine
• No analytics, no tracking, no external servers
• Uses your existing session — no API keys needed
• Open source: github.com/hoya98/chatgpt-export

**Why this exists:**
OpenAI's ChatGPT Team (now Business) plan has never offered a data export option. This has been raised as a GDPR Article 20 (data portability) violation since 2024. We built this because everyone deserves access to their own data.

## Category
Productivity

## Language
English

## Privacy Policy URL
https://hoya98.github.io/chatgpt-export/extension/privacy-policy.html

## Single Purpose Description
This extension exports all ChatGPT conversations from the user's account (including workspace accounts) to a downloadable JSON file.

## Host Permission Justification
The extension needs access to chatgpt.com to:
1. Read the user's authenticated session to make API calls on their behalf
2. Call ChatGPT's conversation listing and retrieval APIs
3. Download file attachments from conversations
4. Trigger the file download of the exported JSON

## Are you using remote code?
No. All code is bundled in the extension package.
