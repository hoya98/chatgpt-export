/**
 * ChatGPT Export - Content Script
 * Runs in the context of chatgpt.com pages.
 */

(function () {
  'use strict';

  const CONFIG = {
    BASE_URL: 'https://chatgpt.com/backend-api',
    SESSION_URL: 'https://chatgpt.com/api/auth/session',
    PAGE_SIZE: 100,
    DELAY_FETCHES: 800,
    DELAY_PAGES: 300,
    DELAY_ATTACHMENTS: 500,
    MAX_RETRIES: 5,
    INITIAL_BACKOFF: 500,
    MAX_BACKOFF: 10000,
  };

  function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  function sendMsg(type, data) {
    chrome.runtime.sendMessage(Object.assign({ type: type }, data));
  }

  function log(msg) {
    sendMsg('export-log', { text: msg });
  }

  async function getAccessToken() {
    const resp = await fetch(CONFIG.SESSION_URL, { credentials: 'include' });
    if (!resp.ok) throw new Error('Not logged in or session expired.');
    const data = await resp.json();
    if (!data.accessToken) throw new Error('No access token found.');
    return data.accessToken;
  }

  function getWorkspaceAccountId() {
    const cookie = document.cookie
      .split(';')
      .find(c => c.trim().startsWith('_account='));
    return cookie ? cookie.split('=')[1].trim() : null;
  }

  function buildHeaders(token, accountId) {
    const h = { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' };
    if (accountId) h['Chatgpt-Account-Id'] = accountId;
    return h;
  }

  async function fetchRetry(url, headers) {
    let delay = CONFIG.INITIAL_BACKOFF;
    for (let i = 0; i < CONFIG.MAX_RETRIES; i++) {
      const resp = await fetch(url, { headers: headers, credentials: 'include' });
      if (resp.ok) return resp;
      if (resp.status === 429) {
        const ra = resp.headers.get('retry-after');
        const wait = ra ? parseInt(ra) * 1000 : delay;
        log('Rate limited, waiting ' + wait + 'ms...');
        await sleep(wait);
        delay = Math.min(delay * 2, CONFIG.MAX_BACKOFF);
      } else {
        throw new Error('HTTP ' + resp.status);
      }
    }
    throw new Error('Max retries exceeded');
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

  async function runExport(options) {
    try {
      sendMsg('export-status', { text: 'Authenticating...' });

      const token = await getAccessToken();
      const accountId = getWorkspaceAccountId();
      const headers = buildHeaders(token, accountId);
      log('Authenticated.' + (accountId ? ' Workspace detected.' : ' Personal account.'));

      // List conversations
      sendMsg('export-status', { text: 'Listing...' });
      const allMeta = [];
      let offset = 0;

      while (true) {
        const resp = await fetchRetry(
          CONFIG.BASE_URL + '/conversations?offset=' + offset + '&limit=' + CONFIG.PAGE_SIZE,
          headers
        );
        const data = await resp.json();
        allMeta.push(...data.items);
        log('Found ' + allMeta.length + ' conversations...');
        sendMsg('export-stats', { conversations: allMeta.length });
        if (data.items.length < CONFIG.PAGE_SIZE) break;
        offset += CONFIG.PAGE_SIZE;
        await sleep(CONFIG.DELAY_PAGES);
      }

      // Archived
      if (options.includeArchived) {
        const archResp = await fetchRetry(
          CONFIG.BASE_URL + '/conversations?offset=0&limit=' + CONFIG.PAGE_SIZE + '&is_archived=true',
          headers
        );
        const archData = await archResp.json();
        if (archData.items && archData.items.length > 0) {
          allMeta.push(...archData.items);
          log('Added ' + archData.items.length + ' archived conversations.');
          sendMsg('export-stats', { conversations: allMeta.length });
        }
      }

      log('Total: ' + allMeta.length + ' conversations to export.');

      // Fetch each conversation
      sendMsg('export-status', { text: 'Downloading...' });
      const conversations = [];
      const fileAttachments = {};
      const errors = [];

      for (let i = 0; i < allMeta.length; i++) {
        const c = allMeta[i];
        try {
          const resp = await fetchRetry(CONFIG.BASE_URL + '/conversation/' + c.id, headers);
          const full = await resp.json();
          conversations.push({
            id: c.id,
            title: c.title,
            create_time: c.create_time,
            update_time: c.update_time,
            conversation: full,
          });

          // Extract attachment IDs
          if (full.mapping) {
            Object.keys(full.mapping).forEach(function (key) {
              var node = full.mapping[key];
              if (node && node.message && node.message.metadata && node.message.metadata.attachments) {
                node.message.metadata.attachments.forEach(function (att) {
                  if (att.id && !fileAttachments[att.id]) {
                    fileAttachments[att.id] = { name: att.name || att.id, conversationId: c.id };
                  }
                });
              }
              if (node && node.message && node.message.content && node.message.content.parts) {
                node.message.content.parts.forEach(function (part) {
                  if (part && typeof part === 'object' && part.asset_pointer) {
                    var ptr = part.asset_pointer;
                    if (ptr.startsWith('file-service://')) {
                      var fid = ptr.replace('file-service://', '');
                      if (!fileAttachments[fid]) {
                        fileAttachments[fid] = { name: fid, conversationId: c.id };
                      }
                    }
                  }
                });
              }
            });
          }

          sendMsg('export-progress', { current: i + 1, total: allMeta.length });
          sendMsg('export-stats', { attachments: Object.keys(fileAttachments).length });
        } catch (err) {
          errors.push({ id: c.id, title: c.title, error: err.message });
          conversations.push({ id: c.id, title: c.title, error: err.message });
          log('Error: ' + (c.title || c.id) + ' - ' + err.message);
          sendMsg('export-progress', { current: i + 1, total: allMeta.length });
        }

        await sleep(CONFIG.DELAY_FETCHES);
      }

      // Build export
      sendMsg('export-status', { text: 'Packaging...' });
      log('Building export file...');

      var exportData = {
        export_time: new Date().toISOString(),
        source: 'chatgpt-export (github.com/hoya98/chatgpt-export)',
        workspace_account_id: accountId || null,
        conversation_count: conversations.length,
        attachment_count: Object.keys(fileAttachments).length,
        errors: errors,
        attachments: fileAttachments,
        conversations: conversations,
      };

      var jsonStr = JSON.stringify(exportData, null, 2);
      var blob = new Blob([jsonStr], { type: 'application/json' });
      var dateStr = new Date().toISOString().slice(0, 10);
      triggerDownload(blob, 'chatgpt-export-' + dateStr + '.json');

      log('Exported ' + conversations.length + ' conversations (~' + Math.round(jsonStr.length / 1024 / 1024) + ' MB)');

      // Download attachments if requested
      if (options.includeAttachments && Object.keys(fileAttachments).length > 0) {
        sendMsg('export-status', { text: 'Attachments...' });
        var fileIds = Object.keys(fileAttachments);
        var downloaded = 0;
        var attachErrors = 0;

        for (var f = 0; f < fileIds.length; f++) {
          var fid = fileIds[f];
          var fname = fileAttachments[fid].name;
          try {
            var fresp = await fetchRetry(CONFIG.BASE_URL + '/files/' + fid + '/download', headers);
            var ct = fresp.headers.get('content-type');
            if (ct && ct.includes('application/json')) {
              var jdata = await fresp.json();
              if (jdata.download_url) {
                var dlResp = await fetch(jdata.download_url);
                var dlBlob = await dlResp.blob();
                triggerDownload(dlBlob, fname);
              }
            } else {
              var fblob = await fresp.blob();
              triggerDownload(fblob, fname);
            }
            downloaded++;
          } catch (e) {
            attachErrors++;
          }
          sendMsg('export-progress', { current: f + 1, total: fileIds.length });
          await sleep(CONFIG.DELAY_ATTACHMENTS);
        }
        log('Attachments: ' + downloaded + ' downloaded, ' + attachErrors + ' failed.');
      }

      sendMsg('export-done', {
        conversations: conversations.length,
        attachments: Object.keys(fileAttachments).length,
      });

    } catch (err) {
      sendMsg('export-error', { text: err.message });
    }
  }

  // Listen for messages from popup
  chrome.runtime.onMessage.addListener(function (msg) {
    if (msg.action === 'startExport') {
      runExport(msg.options || {});
    }
  });
})();
