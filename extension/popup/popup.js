document.addEventListener('DOMContentLoaded', () => {
  const exportBtn = document.getElementById('exportBtn');
  const statusText = document.getElementById('statusText');
  const convCount = document.getElementById('convCount');
  const attachCount = document.getElementById('attachCount');
  const progressContainer = document.getElementById('progressContainer');
  const progressFill = document.getElementById('progressFill');
  const progressText = document.getElementById('progressText');
  const warningBox = document.getElementById('warningBox');
  const logArea = document.getElementById('logArea');
  const includeAttachments = document.getElementById('includeAttachments');
  const includeArchived = document.getElementById('includeArchived');

  function addLog(msg) {
    logArea.style.display = 'block';
    const line = document.createElement('div');
    line.textContent = msg;
    logArea.appendChild(line);
    logArea.scrollTop = logArea.scrollHeight;
  }

  function setStatus(text, type) {
    statusText.textContent = text;
    statusText.className = 'status-value' + (type ? ' ' + type : '');
  }

  function updateProgress(current, total) {
    progressContainer.style.display = 'block';
    const pct = total > 0 ? Math.round((current / total) * 100) : 0;
    progressFill.style.width = pct + '%';
    progressText.textContent = current + ' / ' + total;
  }

  // Check if we're on chatgpt.com
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    const tab = tabs[0];
    if (!tab || !tab.url || !tab.url.startsWith('https://chatgpt.com')) {
      warningBox.style.display = 'block';
      exportBtn.disabled = true;
      setStatus('Wrong page', 'error');
    }
  });

  exportBtn.addEventListener('click', () => {
    exportBtn.disabled = true;
    setStatus('Exporting...', '');
    addLog('Starting export...');

    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      const tab = tabs[0];

      chrome.tabs.sendMessage(tab.id, {
        action: 'startExport',
        options: {
          includeAttachments: includeAttachments.checked,
          includeArchived: includeArchived.checked,
        },
      });
    });
  });

  // Listen for progress messages from content script
  chrome.runtime.onMessage.addListener((msg) => {
    if (msg.type === 'export-log') {
      addLog(msg.text);
    }
    if (msg.type === 'export-status') {
      setStatus(msg.text, msg.statusType || '');
    }
    if (msg.type === 'export-progress') {
      updateProgress(msg.current, msg.total);
    }
    if (msg.type === 'export-stats') {
      if (msg.conversations !== undefined) convCount.textContent = msg.conversations;
      if (msg.attachments !== undefined) attachCount.textContent = msg.attachments;
    }
    if (msg.type === 'export-done') {
      setStatus('Done!', '');
      convCount.textContent = msg.conversations || '-';
      attachCount.textContent = msg.attachments || '-';
      exportBtn.disabled = false;
      exportBtn.textContent = 'Export Again';
      addLog('Export complete! File downloaded.');
    }
    if (msg.type === 'export-error') {
      setStatus('Error', 'error');
      addLog('ERROR: ' + msg.text);
      exportBtn.disabled = false;
    }
  });
});
