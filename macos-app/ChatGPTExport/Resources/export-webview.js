/**
 * ChatGPT Export - WebView Export Script
 *
 * Adapted from the Chrome extension content script for use in a native
 * macOS WKWebView. Communicates progress back to Swift via
 * webkit.messageHandlers.<name>.postMessage({...})
 *
 * Options are passed via window.__EXPORT_OPTIONS before this script runs.
 */

(async function ChatGPTWebViewExport() {
  'use strict';

  var options = window.__EXPORT_OPTIONS || {};
  var includeArchived = options.includeArchived !== false;
  var includeAttachments = options.includeAttachments !== false;

  var CONFIG = {
    BASE_URL: 'https://chatgpt.com/backend-api',
    SESSION_URL: 'https://chatgpt.com/api/auth/session',
    PAGE_SIZE: 100,
    DELAY_FETCHES: 800,
    DELAY_PAGES: 300,
    DELAY_ATTACHMENTS: 500,
    MAX_RETRIES: 5,
    INITIAL_BACKOFF: 500,
    MAX_BACKOFF: 10000
  };

  // ── Message helpers (Swift bridge) ─────────────────────────

  function sendLog(msg, isError) {
    try {
      webkit.messageHandlers.exportLog.postMessage({
        text: msg,
        isError: isError || false
      });
    } catch (e) {
      console.log('[ChatGPT Export] ' + msg);
    }
  }

  function sendStatus(status, extra) {
    try {
      var payload = { status: status };
      if (extra) {
        var keys = Object.keys(extra);
        for (var i = 0; i < keys.length; i++) {
          payload[keys[i]] = extra[keys[i]];
        }
      }
      webkit.messageHandlers.exportStatus.postMessage(payload);
    } catch (e) {
      console.log('[ChatGPT Export] Status: ' + status);
    }
  }

  function sendProgress(current, total) {
    try {
      webkit.messageHandlers.exportProgress.postMessage({
        current: current,
        total: total
      });
    } catch (e) {}
  }

  function sendStats(data) {
    try {
      webkit.messageHandlers.exportStats.postMessage(data);
    } catch (e) {}
  }

  function sendDone(data) {
    try {
      webkit.messageHandlers.exportDone.postMessage(data);
    } catch (e) {}
  }

  function sendError(msg) {
    try {
      webkit.messageHandlers.exportError.postMessage({ text: msg });
    } catch (e) {
      console.error('[ChatGPT Export] Error: ' + msg);
    }
  }

  function sendExportData(jsonStr) {
    try {
      webkit.messageHandlers.exportData.postMessage({ data: jsonStr });
    } catch (e) {
      console.error('[ChatGPT Export] Failed to send export data');
    }
  }

  // ── Utilities ──────────────────────────────────────────────

  function sleep(ms) {
    return new Promise(function (resolve) {
      setTimeout(resolve, ms);
    });
  }

  async function getAccessToken() {
    var resp = await fetch(CONFIG.SESSION_URL, { credentials: 'include' });
    if (!resp.ok) throw new Error('Not logged in or session expired.');
    var data = await resp.json();
    if (!data.accessToken) throw new Error('No access token found.');
    return data.accessToken;
  }

  function getWorkspaceAccountId() {
    var cookie = document.cookie
      .split(';')
      .find(function (c) {
        return c.trim().startsWith('_account=');
      });
    return cookie ? cookie.split('=')[1].trim() : null;
  }

  function buildHeaders(token, accountId) {
    var h = {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json'
    };
    if (accountId) {
      h['Chatgpt-Account-Id'] = accountId;
    }
    return h;
  }

  async function fetchRetry(url, headers) {
    var delay = CONFIG.INITIAL_BACKOFF;
    for (var i = 0; i < CONFIG.MAX_RETRIES; i++) {
      var resp = await fetch(url, { headers: headers, credentials: 'include' });
      if (resp.ok) return resp;
      if (resp.status === 429) {
        var ra = resp.headers.get('retry-after');
        var wait = ra ? parseInt(ra) * 1000 : delay;
        sendLog('Rate limited, waiting ' + wait + 'ms (retry ' + (i + 1) + '/' + CONFIG.MAX_RETRIES + ')');
        await sleep(wait);
        delay = Math.min(delay * 2, CONFIG.MAX_BACKOFF);
      } else {
        throw new Error('HTTP ' + resp.status + ': ' + resp.statusText);
      }
    }
    throw new Error('Max retries exceeded for ' + url);
  }

  // ── Main Export ────────────────────────────────────────────

  try {
    // Step 1: Auth
    sendStatus('authenticating');
    sendLog('Getting access token...');

    var token = await getAccessToken();
    var accountId = getWorkspaceAccountId();
    var headers = buildHeaders(token, accountId);

    sendLog('Authenticated.' + (accountId ? ' Workspace: ' + accountId : ' Personal account.'));

    // Step 2: List all conversations
    sendStatus('listing');
    sendLog('Fetching conversation list...');

    var allMeta = [];
    var offset = 0;

    while (true) {
      var listUrl = CONFIG.BASE_URL + '/conversations?offset=' + offset + '&limit=' + CONFIG.PAGE_SIZE;
      var listResp = await fetchRetry(listUrl, headers);
      var listData = await listResp.json();

      allMeta = allMeta.concat(listData.items);
      sendLog('Found ' + allMeta.length + ' conversations...');
      sendStats({ conversations: allMeta.length });

      if (listData.items.length < CONFIG.PAGE_SIZE) break;
      offset += CONFIG.PAGE_SIZE;
      await sleep(CONFIG.DELAY_PAGES);
    }

    // Archived conversations
    if (includeArchived) {
      sendLog('Checking archived conversations...');
      var archUrl = CONFIG.BASE_URL + '/conversations?offset=0&limit=' + CONFIG.PAGE_SIZE + '&is_archived=true';
      var archResp = await fetchRetry(archUrl, headers);
      var archData = await archResp.json();

      if (archData.items && archData.items.length > 0) {
        // Paginate archived too
        allMeta = allMeta.concat(archData.items);
        sendLog('Added ' + archData.items.length + ' archived conversations.');
        sendStats({ conversations: allMeta.length });

        // If there might be more archived pages
        var archOffset = CONFIG.PAGE_SIZE;
        while (archData.items.length >= CONFIG.PAGE_SIZE) {
          archUrl = CONFIG.BASE_URL + '/conversations?offset=' + archOffset + '&limit=' + CONFIG.PAGE_SIZE + '&is_archived=true';
          archResp = await fetchRetry(archUrl, headers);
          archData = await archResp.json();
          if (archData.items && archData.items.length > 0) {
            allMeta = allMeta.concat(archData.items);
            sendLog('Added ' + archData.items.length + ' more archived conversations.');
            sendStats({ conversations: allMeta.length });
          }
          archOffset += CONFIG.PAGE_SIZE;
          await sleep(CONFIG.DELAY_PAGES);
        }
      }
    }

    sendLog('Total: ' + allMeta.length + ' conversations to export.');

    // Step 3: Fetch each conversation
    sendStatus('downloading', { current: 0, total: allMeta.length });
    sendLog('Downloading conversation contents...');

    var conversations = [];
    var fileAttachments = {};
    var errors = [];

    for (var i = 0; i < allMeta.length; i++) {
      var c = allMeta[i];
      try {
        var convUrl = CONFIG.BASE_URL + '/conversation/' + c.id;
        var convResp = await fetchRetry(convUrl, headers);
        var full = await convResp.json();

        conversations.push({
          id: c.id,
          title: c.title,
          create_time: c.create_time,
          update_time: c.update_time,
          conversation: full
        });

        // Extract attachment references
        if (full.mapping) {
          var nodeKeys = Object.keys(full.mapping);
          for (var k = 0; k < nodeKeys.length; k++) {
            var node = full.mapping[nodeKeys[k]];

            // Check metadata attachments
            if (node && node.message && node.message.metadata && node.message.metadata.attachments) {
              var atts = node.message.metadata.attachments;
              for (var a = 0; a < atts.length; a++) {
                if (atts[a].id && !fileAttachments[atts[a].id]) {
                  fileAttachments[atts[a].id] = {
                    name: atts[a].name || atts[a].id,
                    conversationId: c.id,
                    conversationTitle: c.title
                  };
                }
              }
            }

            // Check content parts for file-service:// references
            if (node && node.message && node.message.content && node.message.content.parts) {
              var parts = node.message.content.parts;
              for (var p = 0; p < parts.length; p++) {
                if (parts[p] && typeof parts[p] === 'object' && parts[p].asset_pointer) {
                  var ptr = parts[p].asset_pointer;
                  if (ptr.startsWith('file-service://')) {
                    var fid = ptr.replace('file-service://', '');
                    if (!fileAttachments[fid]) {
                      fileAttachments[fid] = {
                        name: fid,
                        conversationId: c.id,
                        conversationTitle: c.title
                      };
                    }
                  }
                }
              }
            }
          }
        }

        sendStats({
          currentTitle: c.title || 'Untitled',
          attachments: Object.keys(fileAttachments).length
        });
        sendLog('(' + (i + 1) + '/' + allMeta.length + ') ' + (c.title || 'Untitled'));

      } catch (err) {
        errors.push({ id: c.id, title: c.title, error: err.message });
        conversations.push({ id: c.id, title: c.title, error: err.message });
        sendLog('Error: ' + (c.title || c.id) + ' - ' + err.message, true);
        sendStats({ errors: errors.length });
      }

      sendProgress(i + 1, allMeta.length);
      await sleep(CONFIG.DELAY_FETCHES);
    }

    // Step 4: Build export
    sendStatus('packaging');
    sendLog('Building export file...');

    var exportData = {
      export_time: new Date().toISOString(),
      source: 'ChatGPT Export macOS App',
      workspace_account_id: accountId || null,
      conversation_count: conversations.length,
      attachment_count: Object.keys(fileAttachments).length,
      errors: errors,
      attachments: fileAttachments,
      conversations: conversations
    };

    var jsonStr = JSON.stringify(exportData, null, 2);
    var sizeMB = Math.round(jsonStr.length / 1024 / 1024);

    sendLog('Export ready: ' + conversations.length + ' conversations (~' + sizeMB + ' MB)');
    sendLog(Object.keys(fileAttachments).length + ' attachment references found.');

    if (errors.length > 0) {
      sendLog(errors.length + ' conversations had errors.');
    }

    // Send the data to Swift for saving via NSSavePanel
    sendExportData(jsonStr);

    // Signal completion
    sendDone({
      conversations: conversations.length,
      attachments: Object.keys(fileAttachments).length,
      errors: errors.length,
      sizeMB: sizeMB
    });

  } catch (err) {
    sendError(err.message || 'Unknown error during export');
    sendLog('Fatal error: ' + err.message, true);
  }
})();
