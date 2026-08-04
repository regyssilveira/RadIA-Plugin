(function() {
  const DEBUG = true;
  function log(...args) {
    if (DEBUG) console.log('[RadIABridge]', ...args);
  }

  // --- Selector and CSS configuration ---
  const CONFIGS = {
    chatgpt: {
      domain: 'chatgpt.com',
      css: ``,
      getInput: () => document.getElementById('prompt-textarea'),
      getSendButton: () => {
        return document.querySelector('button[data-testid="send-button"]') ||
               document.querySelector('button[data-testid="fruitjuice-send-button"]') ||
               document.querySelector('button[aria-label="Send prompt"]');
      },
      isSignedIn: () => {
        return !!CONFIGS.chatgpt.getInput() &&
          !hasVisibleAuthControl() &&
          !hasPageText([
            'you are using our basic model',
            'voce esta usando o nosso modelo basico',
            'vocÃª estÃ¡ usando o nosso modelo bÃ¡sico'
          ]);
      },
      isGenerating: () => {
        return !!(document.querySelector('button[data-testid="stop-button"]') ||
                  document.querySelector('button[aria-label="Stop generating"]') ||
                  document.querySelector('button[aria-label*="stop" i]') ||
                  document.querySelector('button[aria-label*="parar" i]'));
      },
      getLastResponseElement: () => {
        const turnElements = document.querySelectorAll('[data-testid^="conversation-turn-"]');
        if (turnElements.length === 0) return null;
        for (let i = turnElements.length - 1; i >= 0; i--) {
          const turn = turnElements[i];
          const md = turn.querySelector('.markdown');
          if (md) {
            return md;
          }
        }
        return null;
      }
    },
    gemini: {
      domain: 'gemini.google.com',
      css: ``,
      getInput: () => {
        return document.querySelector('div[contenteditable="true"]') ||
               document.querySelector('.ql-editor') ||
               document.querySelector('textarea');
      },
      getSendButton: () => {
        return document.querySelector('button.send-button') ||
               document.querySelector('button[aria-label="Send"]') ||
               document.querySelector('.send-button-container button');
      },
      isSignedIn: () => {
        return !!CONFIGS.gemini.getInput() && !hasVisibleAuthControl();
      },
      isGenerating: () => {
        // Check whether loading animation or the stop button is visible
        return !!(document.querySelector('stop-button') ||
                  document.querySelector('.loading-spinner') ||
                  document.querySelector('button[aria-label="Stop"]') ||
                  document.querySelector('button[aria-label*="stop" i]') ||
                  document.querySelector('button[aria-label*="parar" i]') ||
                  document.querySelector('button[aria-label*="interromper" i]'));
      },
      getLastResponseElement: () => {
        const chatElements = document.querySelectorAll('message-content, .message-content, .response-content');
        if (chatElements.length === 0) return null;
        return chatElements[chatElements.length - 1];
      }
    }
  };

  // Identifica o site ativo
  let currentSite = null;
  const host = globalThis.location.hostname;
  if (host.includes('chatgpt.com')) {
    currentSite = CONFIGS.chatgpt;
  } else if (host.includes('gemini.google.com')) {
    currentSite = CONFIGS.gemini;
  }

  if (!currentSite) {
    log('Unmapped domain:', host);
    return;
  }

  log('Ponte inicializada para:', host);

  function normalizeText(text) {
    return String(text || '')
      .normalize('NFD')
      .replaceAll(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replaceAll(/\s+/g, ' ')
      .trim();
  }

  function isVisibleElement(el) {
    if (!el) return false;
    const rect = el.getBoundingClientRect();
    const style = globalThis.getComputedStyle(el);
    return rect.width > 0 &&
      rect.height > 0 &&
      style.visibility !== 'hidden' &&
      style.display !== 'none';
  }

  function hasVisibleAuthControl() {
    const authTerms = [
      'entrar',
      'login',
      'log in',
      'sign in',
      'cadastre',
      'sign up',
      'registre',
      'register'
    ];
    const controls = document.querySelectorAll('button, a');
    return Array.from(controls).some(el => {
      const text = normalizeText(el.innerText || el.textContent || el.getAttribute('aria-label'));
      return isVisibleElement(el) && authTerms.some(term => text.includes(term));
    });
  }

  function hasPageText(terms) {
    const text = normalizeText(document.body ? document.body.innerText : '');
    return terms.some(term => text.includes(normalizeText(term)));
  }

  // Injeta CSS customizado para limpar a tela
  function injectCSS() {
    try {
      const head = document.head || document.getElementsByTagName('head')[0];
      if (!head) {
        log('Error: document.head not found for CSS injection.');
        return;
      }
      if (document.getElementById('radia-clean-css')) return;
      const style = document.createElement('style');
      style.id = 'radia-clean-css';
      style.innerHTML = currentSite.css;
      head.appendChild(style);
      log('Cleanup CSS injected.');
    } catch (err) {
      log('Error injecting cleanup CSS:', err);
    }
  }



  // --- Inbound communication (Delphi -> WebView) ---
  if (globalThis.chrome?.webview) {
    // globalThis.chrome.webview.addEventListener is a secure host-to-web channel.
    // event.origin is not present here as messages originate directly from the host Delphi process (bds.exe).
    globalThis.chrome.webview.addEventListener('message', event => {
      if (event.origin && event.origin !== '' && !event.origin.startsWith('file://')) {
        return;
      }
      const msg = event.data;
      log('Message received from Delphi:', msg);

      if (msg?.action === 'send_prompt') {
        const inputEl = currentSite.getInput();
        if (!inputEl) {
          log('Error: input field not found.');
          sendToDelphi({ action: 'error', text: 'Input textarea not found in page.' });
          return;
        }

        // Insere o texto no input
        if (inputEl.tagName === 'TEXTAREA' || inputEl.tagName === 'INPUT') {
          inputEl.value = msg.text;
        } else if (inputEl.getAttribute('contenteditable') === 'true') {
          inputEl.innerText = msg.text;
        }

        // Dispatch the events required to enable the site send button
        inputEl.dispatchEvent(new Event('input', { bubbles: true }));
        inputEl.dispatchEvent(new Event('change', { bubbles: true }));

        // Small delay to let the page framework validate the text
        setTimeout(() => {
          const btn = currentSite.getSendButton();
          if (btn) {
            log('Clicking the official send button...');
            btn.click();
            startMonitoring();
          } else {
            log('Error: send button not found.');
            sendToDelphi({ action: 'error', text: 'Send button not found in page.' });
          }
        }, 150);
      }
    });
  }

  // Envia mensagem de volta para o Delphi
  function sendToDelphi(data) {
    if (globalThis.chrome?.webview) {
      globalThis.chrome.webview.postMessage(data);
    } else {
      log('PostMessage simulation:', data);
    }
  }

  // --- Markdown and format reconstruction ---
  function trimOuterBlankLines(text) {
    if (!text) return '';
    let result = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (result.startsWith('\n')) result = result.substring(1);
    while (result.endsWith('\n')) result = result.substring(0, result.length - 1);
    return result;
  }

  function appendLineBreak(text) {
    if (!text || text.endsWith('\n')) return text;
    return text + '\n';
  }

  function readTextWithLayoutBreaks(node) {
    if (!node) return '';

    if (node.nodeType === 3) {
      return node.nodeValue || '';
    }

    if (node.nodeType !== 1) {
      return '';
    }

    const tagName = node.tagName;
    if (tagName === 'BR') {
      return '\n';
    }

    let text = '';
    node.childNodes.forEach(child => {
      text += readTextWithLayoutBreaks(child);
    });

    const className = String(node.className || '');
    const hasLineRole =
      ('line' in node.dataset) ||
      /\b(?:line|token-line|cm-line|view-line)\b/i.test(className);
    const isBlock =
      ['DIV', 'P', 'LI', 'TR'].includes(tagName) ||
      hasLineRole ||
      globalThis.getComputedStyle(node).display === 'block';

    return isBlock ? appendLineBreak(text) : text;
  }

  function getCodeTextFromElement(codeEl) {
    if (!codeEl) return '';

    const renderedText = trimOuterBlankLines(codeEl.innerText || '');
    if (renderedText.includes('\n')) {
      return renderedText;
    }

    const structuredText = trimOuterBlankLines(readTextWithLayoutBreaks(codeEl));
    if (structuredText.includes('\n')) {
      return structuredText;
    }

    return trimOuterBlankLines(codeEl.textContent || renderedText);
  }

  function getMarkdownFromElement(el) {
    if (!el) return '';
    try {
      const clone = el.cloneNode(true);

      // Remove internal buttons, including copy buttons and injected Insert into Delphi buttons
      const buttons = clone.querySelectorAll('button, .radia-insert-btn, [class*="copy" i]');
      buttons.forEach(btn => btn.remove());

      // Find all pre/code block elements
      const preElements = clone.querySelectorAll('pre');
      preElements.forEach(pre => {
        const codeEl = pre.querySelector('code') || pre;
        let lang = 'code';

        // Tenta extrair a linguagem das classes do code ou do pre
        const classes = (codeEl.getAttribute('class') || '') + ' ' + (pre.getAttribute('class') || '');
        const langMatch = /language-(\w+)/i.exec(classes);
        if (langMatch) {
          lang = langMatch[1];
        } else {
          // Fallback: try to read the code block header in the original page
          const parent = pre.parentElement;
          if (parent) {
            const header = parent.querySelector('.code-header') || parent.querySelector('[class*="header" i]');
            if (header) {
              const headerText = header.innerText.trim().toLowerCase();
              if (headerText && headerText.length < 20) {
                lang = headerText;
              }
            }
          }
        }

        const codeText = getCodeTextFromElement(codeEl);

        // Create the classic Markdown representation for the block
        const markdownText = `\n\`\`\`${lang}\n${codeText}\n\`\`\`\n`;

        const textNode = document.createTextNode(markdownText);
        pre.parentNode.replaceChild(textNode, pre);
      });

      // Add explicit line breaks for common block elements to avoid glued text
      // when extracted in hidden/background tabs where innerText misses layout breaks.
      const blockTags = clone.querySelectorAll('p, li, h1, h2, h3, h4, h5, h6, br');
      blockTags.forEach(tag => {
        if (tag.tagName === 'BR') {
          const brNewline = document.createTextNode('\n');
          tag.parentNode.replaceChild(brNewline, tag);
        } else {
          const beforeNode = document.createTextNode('\n');
          const afterNode = document.createTextNode('\n');
          tag.parentNode.insertBefore(beforeNode, tag);
          tag.parentNode.insertBefore(afterNode, tag.nextSibling);
        }
      });

      // Use textContent to read raw DOM independently of visual rendering and CSS layout
      let markdown = clone.textContent || '';

      // Collapse excessive consecutive line breaks to keep formatting clean
      markdown = markdown.replaceAll(/\n{3,}/g, '\n\n');

      return trimOuterBlankLines(markdown);
    } catch (err) {
      log('Erro ao formatar Markdown do elemento:', err);
      return el.textContent || el.innerText || '';
    }
  }

  // --- MONITORAMENTO DA RESPOSTA (Scraping & Stream) ---
  let monitorInterval = null;
  let lastText = '';
  let generatingTimeout = 0;
  let previousResponseElement = null;
  let wasGeneratingDetected = false;

  function startMonitoring() {
    log('Iniciando monitoramento de resposta...');
    lastText = '';
    generatingTimeout = 0;
    wasGeneratingDetected = false;

    // Capture the last existing response element before starting a new one
    previousResponseElement = currentSite.getLastResponseElement();
    log('Previous response element:', previousResponseElement);

    if (monitorInterval) clearInterval(monitorInterval);

    monitorInterval = setInterval(() => {
      const currentEl = currentSite.getLastResponseElement();

      // If no new element exists yet, wait for the site to create the current prompt response
      if (!currentEl || currentEl === previousResponseElement) {
        log('Waiting for the new response bubble in the DOM...');
        return;
      }

      const text = getMarkdownFromElement(currentEl);
      const isGenerating = currentSite.isGenerating();
      if (isGenerating) {
        wasGeneratingDetected = true;
      }

      if (text && text !== lastText) {
        log('Enviando resposta completa de streaming:', text.length, 'bytes');
        sendToDelphi({
          action: 'update_stream',
          text: text,
          isDone: false
        });
        lastText = text;
        generatingTimeout = 0; // Reset timeout because text content is still growing
      }

      if (!isGenerating && lastText.length > 0) {
        generatingTimeout++;
        // If the stop/loading button was detected before, trust isGenerating=false.
        // Only 2 quiet cycles are required in that case (600ms).
        // If the button was never detected, use a 15-cycle safety quiet period (4.5 seconds).
        const requiredCycles = wasGeneratingDetected ? 2 : 15;
        if (generatingTimeout >= requiredCycles) {
          log('Generation completed.');
          clearInterval(monitorInterval);
          monitorInterval = null;

          // Envia o fechamento final com a resposta consolidada
          sendToDelphi({
            action: 'update_stream',
            text: lastText,
            isDone: true
          });
        }
      } else {
        generatingTimeout = 0;
      }
    }, 300);
  }

  // --- Inject "Insert into Delphi" buttons ---

  let observer = null;
  let injectTimeout = null;

  function injectInsertBtnCSS() {
    try {
      const head = document.head || document.getElementsByTagName('head')[0];
      if (!head) return;
      if (document.getElementById('radia-insert-btn-css')) return;

      const style = document.createElement('style');
      style.id = 'radia-insert-btn-css';
      style.innerHTML = `
        .radia-insert-btn {
          background: rgba(0, 122, 204, 0.85) !important;
          color: #ffffff !important;
          border: 1px solid rgba(255, 255, 255, 0.15) !important;
          border-radius: 4px !important;
          padding: 4px 8px !important;
          font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
          font-size: 11px !important;
          font-weight: 600 !important;
          cursor: pointer !important;
          z-index: 9999 !important;
          transition: all 0.2s ease !important;
          display: inline-flex !important;
          align-items: center !important;
          gap: 4px !important;
          line-height: 1 !important;
        }
        .radia-insert-btn:hover {
          background: rgba(0, 122, 204, 1.0) !important;
          transform: translateY(-1px) !important;
          box-shadow: 0 2px 6px rgba(0, 0, 0, 0.2) !important;
        }
        .radia-insert-btn:active {
          transform: translateY(0) !important;
        }
      `;
      head.appendChild(style);
    } catch (err) {
      log('Error injecting button CSS:', err);
    }
  }

  function handleInsertClick(e, btn, code) {
    e.preventDefault();
    e.stopPropagation();

    const codeText = getCodeTextFromElement(code);

    log('Requesting code application in Delphi:', codeText.length, 'bytes');
    sendToDelphi({
      action: 'apply_code',
      code: codeText
    });

    const span = btn.querySelector('span');
    const originalText = span.innerText;
    span.innerText = 'Inserido!';
    btn.style.background = '#4CAF50';
    setTimeout(() => {
      span.innerText = originalText;
      btn.style.background = '';
    }, 1500);
  }

  function injectButtonIntoPre(pre) {
    if (pre.dataset.radiaInjected === 'true') return;

    const code = pre.querySelector('code');
    if (!code) return;

    const computedStyle = globalThis.getComputedStyle(pre);
    if (computedStyle.position === 'static') {
      pre.style.position = 'relative';
    }

    const btn = document.createElement('button');
    btn.className = 'radia-insert-btn';
    btn.title = 'Insert this code directly into the Delphi editor';
    btn.innerHTML = `
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2.5" stroke-linecap="round"
        stroke-linejoin="round"
        style="display:inline-block; vertical-align:middle; width:12px; height:12px;">
        <polyline points="16 18 22 12 16 6"></polyline>
        <polyline points="8 6 2 12 8 18"></polyline>
      </svg>
      <span>Inserir no Delphi</span>
    `;

    btn.style.position = 'absolute';
    btn.style.top = '8px';
    btn.style.right = '85px';

    btn.addEventListener('click', (e) => handleInsertClick(e, btn, code));

    pre.appendChild(btn);
    pre.dataset.radiaInjected = 'true';
  }

  function injectDelphiButtons() {
    try {
      document.querySelectorAll('pre').forEach(injectButtonIntoPre);
    } catch (err) {
      log('Error injecting buttons into pre elements:', err);
    }
  }

  function scheduleInjection() {
    if (injectTimeout) {
      clearTimeout(injectTimeout);
    }
    injectTimeout = setTimeout(() => {
      if (observer) {
        try {
          observer.disconnect();
        } catch (err) {
          log('Erro ao desconectar observer:', err);
        }
      }

      injectDelphiButtons();

      if (observer && document.body) {
        try {
          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
        } catch (err) {
          log('Erro ao reconectar observer:', err);
        }
      }
    }, 300);
  }

  let loginSignaled = false;
  function checkLoginComplete() {
    if (loginSignaled) return true;
    try {
      if (currentSite.isSignedIn?.()) {
        log('Signed-in session detected. Notifying Delphi.');
        sendToDelphi({ action: 'login_complete' });
        loginSignaled = true;
        return true;
      }
    } catch (err) {
      log('Erro ao checar estado de login:', err);
    }
    return false;
  }

  function initBridge() {
    checkLoginComplete();
    injectCSS();
    injectInsertBtnCSS();
    injectDelphiButtons();

    try {
      if (typeof MutationObserver === 'function') {
        observer = new MutationObserver((mutations) => {
          checkLoginComplete();
          let shouldCheck = false;
          for (let mutation of mutations) {
            // Ignore mutations caused by our direct button injection
            let isOurBtn = false;
            mutation.addedNodes.forEach(node => {
              const isInsertButton = node.classList
                ?.contains('radia-insert-btn');
              const isInsertButtonStyle = node.classList
                ?.contains('radia-insert-btn-css');
              if (isInsertButton || isInsertButtonStyle) {
                isOurBtn = true;
              }
            });
            if (isOurBtn) continue;

            if (mutation.addedNodes.length > 0) {
              shouldCheck = true;
              break;
            }
          }
          if (shouldCheck) {
            scheduleInjection();
          }
        });

        if (document.body) {
          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
          log('Button injection observer and bridge enabled successfully.');
        } else {
          log('Error: document.body is missing while enabling the observer.');
        }
      } else {
        log('Warning: MutationObserver is not supported in this environment.');
      }
    } catch (err) {
      log('Error initializing MutationObserver:', err);
    }
  }

  if (document.body && document.head) {
    initBridge();
  } else {
    document.addEventListener('DOMContentLoaded', initBridge);
  }
})();
