/**
 * Vinny's portfolio chat widget.
 * Drop-in, self-contained, no dependencies.
 *
 * Usage: add one line before </body> on any page you want it to appear:
 *   <script src="assets/js/chat-widget.js" defer></script>
 *
 * Requires: your API Gateway endpoint below must have CORS enabled for
 * whatever origin this script runs on (your CloudFront domain). Testing
 * from PowerShell doesn't hit CORS since browsers are the ones that
 * enforce it — see the note at the end of this file.
 */
(function () {
  'use strict';

  // ── Configuration ──────────────────────────────────────────────────
  const API_URL = 'https://mjo31xn1h1.execute-api.us-east-2.amazonaws.com/chat';
  const BOT_NAME = 'vinny-bot';
  const GREETING =
    "Hey, I'm an AI trained on Vinny's resume and this project. Ask me about his skills, certs, or how this site was built.";

  let sessionId = null;
  let hasGreeted = false;
  let isSending = false;

  // ── Styles ────────────────────────────────────────────────────────
  const style = document.createElement('style');
  style.textContent = `
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&display=swap');

    #vc-root {
      --vc-bg: #0b0f14;
      --vc-panel: #11161d;
      --vc-border: #262d38;
      --vc-text: #d7dee8;
      --vc-muted: #6b7684;
      --vc-accent: #5eead4;
      --vc-user: #93c5fd;
      --vc-error: #f87171;
      --vc-font: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }

    #vc-toggle {
      position: fixed;
      right: 24px;
      bottom: 24px;
      width: 52px;
      height: 52px;
      border-radius: 8px;
      background: var(--vc-panel);
      border: 1px solid var(--vc-border);
      color: var(--vc-accent);
      font-family: var(--vc-font);
      font-size: 18px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 999999;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.35);
      transition: transform 0.15s ease, border-color 0.15s ease;
    }
    #vc-toggle:hover { border-color: var(--vc-accent); transform: translateY(-2px); }
    #vc-toggle:focus-visible { outline: 2px solid var(--vc-accent); outline-offset: 2px; }

    #vc-panel {
      position: fixed;
      right: 24px;
      bottom: 88px;
      width: 340px;
      max-width: calc(100vw - 32px);
      height: 440px;
      max-height: calc(100vh - 120px);
      background: var(--vc-bg);
      border: 1px solid var(--vc-border);
      border-radius: 10px;
      display: none;
      flex-direction: column;
      overflow: hidden;
      font-family: var(--vc-font);
      z-index: 999999;
      box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);
    }
    #vc-panel.vc-open { display: flex; }
    @media (prefers-reduced-motion: no-preference) {
      #vc-panel.vc-open { animation: vc-rise 0.18s ease-out; }
    }
    @keyframes vc-rise {
      from { opacity: 0; transform: translateY(8px); }
      to { opacity: 1; transform: translateY(0); }
    }

    #vc-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 14px;
      background: var(--vc-panel);
      border-bottom: 1px solid var(--vc-border);
      color: var(--vc-muted);
      font-size: 12px;
      flex-shrink: 0;
    }
    #vc-header .vc-accent { color: var(--vc-accent); }
    #vc-close {
      background: none;
      border: none;
      color: var(--vc-muted);
      font-family: var(--vc-font);
      font-size: 14px;
      cursor: pointer;
      line-height: 1;
      padding: 4px;
    }
    #vc-close:hover { color: var(--vc-text); }
    #vc-close:focus-visible { outline: 2px solid var(--vc-accent); outline-offset: 2px; }

    #vc-log {
      flex: 1;
      overflow-y: auto;
      padding: 12px 14px;
      font-size: 13px;
      line-height: 1.6;
    }
    .vc-line { margin-bottom: 10px; white-space: pre-wrap; word-break: break-word; }
    .vc-line .vc-prefix { user-select: none; margin-right: 4px; }
    .vc-line.vc-user .vc-prefix { color: var(--vc-user); }
    .vc-line.vc-bot .vc-prefix { color: var(--vc-accent); }
    .vc-line.vc-error .vc-prefix,
    .vc-line.vc-error .vc-body { color: var(--vc-error); }
    .vc-line .vc-body { color: var(--vc-text); }

    #vc-typing { color: var(--vc-muted); font-size: 13px; padding: 0 14px 8px; flex-shrink: 0; }
    #vc-typing.vc-hidden { display: none; }
    #vc-typing .vc-dot { display: inline-block; animation: vc-blink 1.2s infinite; }
    #vc-typing .vc-dot:nth-child(2) { animation-delay: 0.2s; }
    #vc-typing .vc-dot:nth-child(3) { animation-delay: 0.4s; }
    @keyframes vc-blink { 0%, 60%, 100% { opacity: 0.2; } 30% { opacity: 1; } }

    #vc-inputRow {
      display: flex;
      align-items: center;
      border-top: 1px solid var(--vc-border);
      background: var(--vc-panel);
      padding: 8px 10px;
      flex-shrink: 0;
    }
    #vc-prompt { color: var(--vc-accent); font-size: 13px; margin-right: 6px; }
    #vc-input {
      flex: 1;
      background: transparent;
      border: none;
      color: var(--vc-text);
      font-family: var(--vc-font);
      font-size: 13px;
      outline: none;
      min-width: 0;
    }
    #vc-input::placeholder { color: var(--vc-muted); }
    #vc-input:disabled { opacity: 0.5; }

    @media (max-width: 480px) {
      #vc-panel { right: 12px; left: 12px; width: auto; bottom: 84px; }
      #vc-toggle { right: 16px; bottom: 16px; }
    }
  `;
  document.head.appendChild(style);

  // ── DOM ───────────────────────────────────────────────────────────
  const root = document.createElement('div');
  root.id = 'vc-root';

  const toggle = document.createElement('button');
  toggle.id = 'vc-toggle';
  toggle.type = 'button';
  toggle.setAttribute('aria-label', 'Open chat with vinny-bot');
  toggle.setAttribute('aria-expanded', 'false');
  toggle.textContent = '>_';

  const panel = document.createElement('div');
  panel.id = 'vc-panel';
  panel.setAttribute('role', 'dialog');
  panel.setAttribute('aria-label', 'Chat with vinny-bot');

  const header = document.createElement('div');
  header.id = 'vc-header';
  header.innerHTML = '<span>chat@<span class="vc-accent">vinny-portfolio</span>:~$</span>';
  const closeBtn = document.createElement('button');
  closeBtn.id = 'vc-close';
  closeBtn.type = 'button';
  closeBtn.setAttribute('aria-label', 'Close chat');
  closeBtn.textContent = '[x]';
  header.appendChild(closeBtn);

  const log = document.createElement('div');
  log.id = 'vc-log';
  log.setAttribute('role', 'log');
  log.setAttribute('aria-live', 'polite');

  const typing = document.createElement('div');
  typing.id = 'vc-typing';
  typing.className = 'vc-hidden';
  typing.innerHTML =
    '<span class="vc-accent">' + BOT_NAME + '</span> is typing' +
    '<span class="vc-dot">.</span><span class="vc-dot">.</span><span class="vc-dot">.</span>';

  const inputRow = document.createElement('div');
  inputRow.id = 'vc-inputRow';
  const prompt = document.createElement('span');
  prompt.id = 'vc-prompt';
  prompt.textContent = '$';
  const input = document.createElement('input');
  input.id = 'vc-input';
  input.type = 'text';
  input.placeholder = 'Ask about Vinny...';
  input.autocomplete = 'off';
  input.setAttribute('aria-label', 'Type a message');
  inputRow.appendChild(prompt);
  inputRow.appendChild(input);

  panel.appendChild(header);
  panel.appendChild(log);
  panel.appendChild(typing);
  panel.appendChild(inputRow);

  root.appendChild(toggle);
  root.appendChild(panel);
  document.body.appendChild(root);

  // ── Helpers ───────────────────────────────────────────────────────
  function addLine(kind, prefixText, bodyText) {
    const line = document.createElement('div');
    line.className = 'vc-line vc-' + kind;

    const prefix = document.createElement('span');
    prefix.className = 'vc-prefix';
    prefix.textContent = prefixText;

    const body = document.createElement('span');
    body.className = 'vc-body';
    body.textContent = bodyText; // textContent only — never innerHTML for dynamic content

    line.appendChild(prefix);
    line.appendChild(body);
    log.appendChild(line);
    log.scrollTop = log.scrollHeight;
  }

  function setSending(state) {
    isSending = state;
    input.disabled = state;
    typing.classList.toggle('vc-hidden', !state);
    if (!state) input.focus();
  }

  function openPanel() {
    panel.classList.add('vc-open');
    toggle.setAttribute('aria-expanded', 'true');
    if (!hasGreeted) {
      addLine('bot', BOT_NAME + ':', GREETING);
      hasGreeted = true;
    }
    input.focus();
  }

  function closePanel() {
    panel.classList.remove('vc-open');
    toggle.setAttribute('aria-expanded', 'false');
    toggle.focus();
  }

  async function sendMessage(message) {
    setSending(true);
    try {
      const payload = { message: message };
      if (sessionId) payload.session_id = sessionId;

      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const data = await res.json().catch(function () { return null; });

      if (!res.ok) {
        const msg =
          (data && data.error) ||
          (res.status === 429
            ? "Too many messages — give it a moment and try again."
            : 'Something went wrong on the backend. Try again in a bit.');
        addLine('error', BOT_NAME + ':', msg);
        return;
      }

      if (data && data.session_id) sessionId = data.session_id;
      addLine('bot', BOT_NAME + ':', (data && data.reply) || '(no reply received)');
    } catch (err) {
      addLine('error', BOT_NAME + ':', "Couldn't reach the server — check your connection and try again.");
    } finally {
      setSending(false);
    }
  }

  // ── Events ────────────────────────────────────────────────────────
  toggle.addEventListener('click', function () {
    if (panel.classList.contains('vc-open')) closePanel();
    else openPanel();
  });

  closeBtn.addEventListener('click', closePanel);

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && panel.classList.contains('vc-open')) closePanel();
  });

  input.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter' || isSending) return;
    const value = input.value.trim();
    if (!value) return;
    addLine('user', '$', value);
    input.value = '';
    sendMessage(value);
  });
})();

/**
 * IMPORTANT — CORS
 * ─────────────────
 * Your PowerShell tests worked because CORS is a browser-enforced rule,
 * not a server one — Invoke-RestMethod never checks it. Once this script
 * runs in an actual browser tab on your CloudFront domain, API Gateway
 * must respond with the right Access-Control-Allow-* headers or every
 * request will fail silently with a CORS error in the console.
 *
 * In your Terraform, make sure the /chat route:
 *   1. Has an OPTIONS method (or CORS configured directly, if you're on
 *      HTTP API rather than REST API — HTTP APIs support a built-in
 *      `cors_configuration` block on the aws_apigatewayv2_api resource).
 *   2. Returns Access-Control-Allow-Origin set to your CloudFront domain
 *      (or "*" while testing, tightened once it's live).
 *   3. Your Lambda's actual responses (not just the OPTIONS preflight)
 *      also include Access-Control-Allow-Origin in their headers, if
 *      you're using Lambda proxy integration — API Gateway's CORS config
 *      alone does not add headers to proxy-integration responses.
 */