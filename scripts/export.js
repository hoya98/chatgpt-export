/**
 * ChatGPT Workspace Exporter
 *
 * Bulk exports all conversations from ChatGPT, including Team/Business workspaces
 * where OpenAI doesn't provide a native export option.
 *
 * Usage: Run in the browser console while logged into chatgpt.com
 *
 * MIT License - https://github.com/hoya98/chatgpt-export
 */

(async function ChatGPTExport() {
  'use strict';

  const CONFIG = {
    BASE_URL: 'https://chatgpt.com/backend-api',
    SESSION_URL: 'https://chatgpt.com/api/auth/session',
    PAGE_SIZE: 100,
    DELAY_BETWEEN_FETCHES: 800,
    DELAY_BETWEEN_PAGES: 300,
    DELAY_BETWEEN_ATTACHMENTS: 500,
    MAX_RETRIES: 5,
    INITIAL_BACKOFF: 500,
    MAX_BACKOFF: 10000,
  };

  // ── Helpers ──────────────────────────────────────────────

  function log(msg) {
    console.log(`[ChatGPT Export] ${msg}`);
  }

  function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async function getAccessToken() {
    const resp = await fetch(CONFIG.SESSION_URL, { credentials: 'include' });
    if (!resp.ok) throw new Error('Failed to get session. Are you logged in?');
    const data = await resp.json();
    if (!data.accessToken) throw new Error('No access token in session response.');
    return data.accessToken;
  }

  function getWorkspaceAccountId() {
    const cookie = document.cookie
      .split(';')
      .find(c => c.trim().startsWith('_account='));
    return cookie ? cookie.split('=')[1].trim() : null;
  }

  function buildHeaders(token, accountId) {
    const headers = {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
    };
    if (accountId) {
      headers['Chatgpt-Account-Id'] = accountId;
    }
    return headers;
  }

  async function fetchWithRetry(url, headers, retries) {
    retries = retries || CONFIG.MAX_RETRIES;
    let delay = CONFIG.INITIAL_BACKOFF;
    for (let i = 0; i < retries; i++) {
      const resp = await fetch(url, { headers: headers, credentials: 'include' });
      if (resp.ok) return resp;
      if (resp.status === 429) {
        const retryAfter = resp.headers.get('retry-after');
        const waitMs = retryAfter ? parseInt(retryAfter) * 1000 : delay;
        log('Rate limited. Waiting ' + waitMs + 'ms (retry ' + (i + 1) + '/' + retries + ')');
        await sleep(waitMs);
        delay = Math.min(delay * 2, CONFIG.MAX_BACKOFF);
      } else {
        throw new Error('HTTP ' + resp.status + ': ' + resp.statusText);
      }
    }
    throw new Error('Failed after ' + retries + ' retries for ' + url);
  }

  function triggerDownload(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  // ── Main Export ──────────────────────────────────────────

  log('Starting export...');

  // Step 1: Auth
  log('Getting access token...');
  const token = await getAccessToken();
  const accountId = getWorkspaceAccountId();
  const headers = buildHeaders(token, accountId);
  log('Authenticated.' + (accountId ? ' Workspace: ' + accountId : ' Personal account.'));

  // Step 2: List all conversations with pagination
  log('Fetching conversation list...');
  const allConversations = [];
  let offset = 0;

  while (true) {
    const url = CONFIG.BASE_URL + '/conversations?offset=' + offset + '&limit=' + CONFIG.PAGE_SIZE;
    const resp = await fetchWithRetry(url, headers);
    const data = await resp.json();
    allConversations.push(...data.items);
    log('Listed ' + allConversations.length + ' conversations...');
    if (data.items.length < CONFIG.PAGE_SIZE) break;
    offset += CONFIG.PAGE_SIZE;
    await sleep(CONFIG.DELAY_BETWEEN_PAGES);
  }

  // Also fetch archived conversations
  log('Checking for archived conversations...');
  const archResp = await fetchWithRetry(
    CONFIG.BASE_URL + '/conversations?offset=0&limit=' + CONFIG.PAGE_SIZE + '&is_archived=true',
    headers
  );
  const archData = await archResp.json();
  if (archData.items && archData.items.length > 0) {
    allConversations.push(...archData.items);
    log('Found ' + archData.items.length + ' archived conversations.');
  }

  log('Total conversations to export: ' + allConversations.length);

  // Step 3: Fetch full content of each conversation
  log('Fetching conversation contents...');
  const fullConversations = [];
  const fileAttachments = {};
  const errors = [];

  for (let i = 0; i < allConversations.length; i++) {
    const conv = allConversations[i];
    try {
      const resp = await fetchWithRetry(CONFIG.BASE_URL + '/conversation/' + conv.id, headers);
      const fullData = await resp.json();

      fullConversations.push({
        id: conv.id,
        title: conv.title,
        create_time: conv.create_time,
        update_time: conv.update_time,
        conversation: fullData,
      });

      // Extract file attachment IDs
      if (fullData.mapping) {
        const keys = Object.keys(fullData.mapping);
        for (let k = 0; k < keys.length; k++) {
          const node = fullData.mapping[keys[k]];
          // Check metadata attachments
          if (node && node.message && node.message.metadata && node.message.metadata.attachments) {
            const atts = node.message.metadata.attachments;
            for (let a = 0; a < atts.length; a++) {
              if (atts[a].id && !fileAttachments[atts[a].id]) {
                fileAttachments[atts[a].id] = {
                  name: atts[a].name || atts[a].id,
                  conversationId: conv.id,
                  conversationTitle: conv.title,
                };
              }
            }
          }
          // Check content parts for file-service:// references
          if (node && node.message && node.message.content && node.message.content.parts) {
            const parts = node.message.content.parts;
            for (let p = 0; p < parts.length; p++) {
              if (parts[p] && typeof parts[p] === 'object' && parts[p].asset_pointer) {
                const ptr = parts[p].asset_pointer;
                if (ptr.startsWith('file-service://')) {
                  const fid = ptr.replace('file-service://', '');
                  if (!fileAttachments[fid]) {
                    fileAttachments[fid] = {
                      name: fid,
                      conversationId: conv.id,
                      conversationTitle: conv.title,
                    };
                  }
                }
              }
            }
          }
        }
      }

      log('(' + (i + 1) + '/' + allConversations.length + ') ' + (conv.title || 'Untitled'));
    } catch (err) {
      log('ERROR: ' + conv.id + ' - ' + err.message);
      errors.push({ id: conv.id, title: conv.title, error: err.message });
      fullConversations.push({ id: conv.id, title: conv.title, error: err.message });
    }

    await sleep(CONFIG.DELAY_BETWEEN_FETCHES);
  }

  // Step 4: Build and download export
  log('Building export file...');
  const exportData = {
    export_time: new Date().toISOString(),
    source: 'chatgpt-export (github.com/hoya98/chatgpt-export)',
    workspace_account_id: accountId || null,
    conversation_count: fullConversations.length,
    attachment_count: Object.keys(fileAttachments).length,
    errors: errors,
    attachments: fileAttachments,
    conversations: fullConversations,
  };

  const jsonStr = JSON.stringify(exportData, null, 2);
  const blob = new Blob([jsonStr], { type: 'application/json' });
  const dateStr = new Date().toISOString().slice(0, 10);
  const filename = 'chatgpt-export-' + dateStr + '.json';

  triggerDownload(blob, filename);

  const sizeMB = Math.round(jsonStr.length / 1024 / 1024);
  log('Done! Exported ' + fullConversations.length + ' conversations (~' + sizeMB + ' MB)');
  log(Object.keys(fileAttachments).length + ' attachment references found.');
  if (errors.length > 0) {
    log(errors.length + ' conversations had errors (see export file for details).');
  }

  return {
    conversations: fullConversations.length,
    attachments: Object.keys(fileAttachments).length,
    errors: errors.length,
    filename: filename,
  };
})();
