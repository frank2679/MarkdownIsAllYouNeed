/**
 * MarkdownIsAllYouNeed - WYSIWYG Editor
 *
 * MVP-0: Lightweight contentEditable-based editor with markdown I/O.
 * Uses a simple markdown→HTML→markdown roundtrip.
 * Will be replaced by full Milkdown integration when npm build pipeline is set up.
 *
 * Bridge protocol (version 1):
 *   Native → JS:  window.bridge.receive({ action, version, payload })
 *   JS → Native:  webkit.messageHandlers.bridge.postMessage({ action, version, payload })
 */

(function() {
    'use strict';

    const editor = document.getElementById('editor');
    editor.contentEditable = true;
    editor.spellcheck = true;

    let isDirty = false;
    let currentMarkdown = '';
    let currentMode = 'edit'; // 'preview' | 'edit'
    let currentBasePath = null; // file:// directory URL for resolving relative image paths

    // =========================================================================
    // Bridge: unified communication protocol
    // =========================================================================

    window.bridge = {
        receive: function(message) {
            const { action, version, payload } = message;
            if (version !== 1) {
                console.warn('Unknown bridge version:', version);
                return;
            }

            switch (action) {
                case 'setContent':
                    setContent(payload.markdown || '', payload.basePath || null);
                    break;
                case 'getContent':
                    sendToNative('contentReady', { markdown: getMarkdown() });
                    break;
                case 'setMode':
                    setMode(payload.mode || 'edit');
                    break;
                case 'insertImage':
                    insertImage(payload.path, payload.alt || '');
                    break;
                case 'formatText':
                    applyFormat(payload.format);
                    break;
                case 'setFontSize':
                    document.body.style.fontSize = payload.size + 'px';
                    break;
                default:
                    console.warn('Unknown action:', action);
            }
        }
    };

    function sendToNative(action, payload) {
        try {
            webkit.messageHandlers.bridge.postMessage({
                action: action,
                version: 1,
                payload: payload
            });
        } catch (e) {
            // Not in WKWebView (debugging in browser)
            console.log('→ Native:', action, payload);
        }
    }

    // =========================================================================
    // Markdown → HTML parser (simple but covers MVP elements)
    // =========================================================================

    function markdownToHTML(md) {
        let html = md;

        // Escape HTML entities first
        // (skip this to allow raw HTML passthrough for now)

        // Code blocks (``` ... ```)
        html = html.replace(/```(\w*)\n([\s\S]*?)```/g, function(_, lang, code) {
            const escaped = escapeHtml(code.trimEnd());
            return '<pre><code class="language-' + (lang || 'text') + '">' + escaped + '</code></pre>';
        });

        // Inline code
        html = html.replace(/`([^`\n]+)`/g, '<code>$1</code>');

        // Headings
        html = html.replace(/^######\s+(.+)$/gm, '<h6>$1</h6>');
        html = html.replace(/^#####\s+(.+)$/gm, '<h5>$1</h5>');
        html = html.replace(/^####\s+(.+)$/gm, '<h4>$1</h4>');
        html = html.replace(/^###\s+(.+)$/gm, '<h3>$1</h3>');
        html = html.replace(/^##\s+(.+)$/gm, '<h2>$1</h2>');
        html = html.replace(/^#\s+(.+)$/gm, '<h1>$1</h1>');

        // Horizontal rules
        html = html.replace(/^---+$/gm, '<hr>');
        html = html.replace(/^\*\*\*+$/gm, '<hr>');

        // Blockquotes
        html = html.replace(/^>\s+(.+)$/gm, '<blockquote><p>$1</p></blockquote>');

        // Images — resolve relative paths via localfile:// custom scheme for sandbox access
        html = html.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, function(_, alt, src) {
            if (currentBasePath
                && !src.startsWith('http')
                && !src.startsWith('data:')
                && !src.startsWith('localfile://')) {
                // currentBasePath is a filesystem path (e.g. /var/mobile/.../Documents/repos/myrepo)
                var fullPath = src.startsWith('/') ? src : currentBasePath + '/' + src;
                src = 'localfile://' + fullPath;
            }
            return '<img src="' + src + '" alt="' + alt + '">';
        });

        // Links
        html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

        // Auto-link bare URLs (not already inside an HTML attribute like href="..." or src="...")
        html = html.replace(/(?<![="'(])https?:\/\/[^\s<>"')\]]+/g, function(url) {
            return '<a href="' + url + '">' + url + '</a>';
        });

        // Bold + Italic
        html = html.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
        html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');

        // Strikethrough
        html = html.replace(/~~(.+?)~~/g, '<del>$1</del>');

        // Task lists
        html = html.replace(/^- \[x\]\s+(.+)$/gm, '<li data-task="checked">$1</li>');
        html = html.replace(/^- \[ \]\s+(.+)$/gm, '<li data-task="unchecked">$1</li>');

        // Unordered lists
        html = html.replace(/^[-*]\s+(.+)$/gm, '<li>$1</li>');

        // Ordered lists — use data-ol marker to distinguish from unordered
        html = html.replace(/^\d+\.\s+(.+)$/gm, '<li data-ol>$1</li>');

        // Wrap consecutive <li data-ol> in <ol> (ordered lists)
        html = html.replace(/((?:<li data-ol>.*<\/li>\n?)+)/g, function(match) {
            return '<ol>' + match.replace(/ data-ol/g, '') + '</ol>';
        });

        // Wrap remaining consecutive <li> in <ul> (unordered + task lists)
        html = html.replace(/((?:<li[^>]*>.*<\/li>\n?)+)/g, '<ul>$1</ul>');

        // Merge adjacent blockquotes
        html = html.replace(/<\/blockquote>\n<blockquote>/g, '\n');

        // Tables (must run before paragraph wrapping)
        html = parseTables(html);

        // --- Paragraph Wrapping ---
        // To prevent wrapping lines INSIDE <pre> or <table> tags into paragraphs,
        // we temporarily extract them and replace with placeholders.
        const blocks = [];
        html = html.replace(/<(pre|table)[\s\S]*?<\/\1>/g, function(match) {
            blocks.push(match);
            return '<!--BLOCK' + (blocks.length - 1) + '-->';
        });

        // Paragraphs: wrap remaining text blocks
        html = html.replace(/^(?!<[hupbloitd]|<\/|<hr|<img|<a |<!--)(.+)$/gm, '<p>$1</p>');

        // Restore blocks
        html = html.replace(/<!--BLOCK(\d+)-->/g, function(_, index) {
            return blocks[parseInt(index)];
        });

        // Clean up empty paragraphs
        html = html.replace(/<p><\/p>/g, '');

        return html;
    }

    function parseTables(html) {
        const lines = html.split('\n');
        let inTable = false;
        let tableLines = [];
        let newLines = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.startsWith('|') && line.endsWith('|')) {
                if (!inTable) {
                    inTable = true;
                    tableLines = [line];
                } else {
                    tableLines.push(line);
                }
            } else {
                if (inTable) {
                    newLines.push(renderTable(tableLines));
                    inTable = false;
                    tableLines = [];
                }
                newLines.push(lines[i]);
            }
        }
        if (inTable) {
            newLines.push(renderTable(tableLines));
        }
        return newLines.join('\n');
    }

    function renderTable(lines) {
        if (lines.length < 2) return lines.join('\n');

        // Check for separator line (| --- | --- |)
        const separatorLine = lines[1].trim();
        const hasSeparator = separatorLine.match(/^\|?\s*:?-+:?\s*(\|?\s*:?-+:?\s*\|?)*$/);
        if (!hasSeparator) return lines.join('\n');

        // Extract alignments from separator
        const alignments = separatorLine.split('|')
            .filter((_, i, arr) => i > 0 && i < arr.length - 1)
            .map(s => {
                const trimmed = s.trim();
                if (trimmed.startsWith(':') && trimmed.endsWith(':')) return 'center';
                if (trimmed.endsWith(':')) return 'right';
                return 'left';
            });

        let html = '<table>';
        lines.forEach((line, index) => {
            if (index === 1) return; // Skip separator

            const cells = line.trim().split('|').filter((_, i, arr) => i > 0 && i < arr.length - 1);
            const tag = index === 0 ? 'th' : 'td';
            
            if (index === 0) html += '<thead>';
            if (index === 2) html += '<tbody>';
            
            html += '<tr>';
            cells.forEach((cell, i) => {
                const align = alignments[i] || 'left';
                html += '<' + tag + ' style="text-align: ' + align + '">' + cell.trim() + '</' + tag + '>';
            });
            html += '</tr>';

            if (index === 0) html += '</thead>';
        });
        html += '</tbody></table>';
        return html;
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // =========================================================================
    // HTML → Markdown converter
    // =========================================================================

    function htmlToMarkdown(html) {
        const tempDiv = document.createElement('div');
        tempDiv.innerHTML = html;
        let md = nodeToMarkdown(tempDiv);

        // Normalize: collapse 3+ consecutive blank lines to max 2 (iOS contentEditable tends to insert extra divs)
        md = md.replace(/\n{3,}/g, '\n\n');

        // Trim leading whitespace but preserve a single trailing newline (standard file convention)
        md = md.replace(/^\s+/, '');
        md = md.trimEnd() + '\n';

        return md;
    }

    function nodeToMarkdown(node) {
        let result = '';

        for (const child of node.childNodes) {
            if (child.nodeType === Node.TEXT_NODE) {
                result += child.textContent;
                continue;
            }

            if (child.nodeType !== Node.ELEMENT_NODE) continue;

            const tag = child.tagName.toLowerCase();
            const inner = nodeToMarkdown(child);

            switch (tag) {
                case 'h1': result += '\n# ' + inner + '\n\n'; break;
                case 'h2': result += '\n## ' + inner + '\n\n'; break;
                case 'h3': result += '\n### ' + inner + '\n\n'; break;
                case 'h4': result += '\n#### ' + inner + '\n\n'; break;
                case 'h5': result += '\n##### ' + inner + '\n\n'; break;
                case 'h6': result += '\n###### ' + inner + '\n\n'; break;
                case 'p': result += inner + '\n\n'; break;
                case 'br': result += '\n'; break;
                case 'strong':
                case 'b': result += '**' + inner + '**'; break;
                case 'em':
                case 'i': result += '*' + inner + '*'; break;
                case 'del':
                case 's': result += '~~' + inner + '~~'; break;
                case 'code':
                    if (child.parentElement && child.parentElement.tagName === 'PRE') {
                        result += inner;
                    } else {
                        result += '`' + inner + '`';
                    }
                    break;
                case 'pre':
                    const codeEl = child.querySelector('code');
                    const lang = codeEl ? (codeEl.className.replace('language-', '') || '') : '';
                    const code = codeEl ? codeEl.textContent : child.textContent;
                    result += '\n```' + lang + '\n' + code + '\n```\n\n';
                    break;
                case 'blockquote':
                    const lines = inner.trim().split('\n');
                    result += '\n' + lines.map(l => '> ' + l).join('\n') + '\n\n';
                    break;
                case 'a':
                    const href = child.getAttribute('href') || '';
                    // Auto-linked URL (text === href) → restore as bare URL
                    result += (inner.trim() === href.trim()) ? href : '[' + inner + '](' + href + ')';
                    break;
                case 'img':
                    let src = child.getAttribute('src') || '';
                    const alt = child.getAttribute('alt') || '';
                    // Convert localfile:// back to relative path for markdown storage
                    if (src.startsWith('localfile://') && currentBasePath) {
                        const prefix = 'localfile://' + currentBasePath + '/';
                        if (src.startsWith(prefix)) {
                            src = src.slice(prefix.length);
                        } else {
                            src = src.slice('localfile://'.length);
                        }
                    }
                    result += '![' + alt + '](' + src + ')';
                    break;
                case 'hr': result += '\n---\n\n'; break;
                case 'ul':
                case 'ol':
                    let listIndex = 1;
                    for (const li of child.children) {
                        if (li.tagName === 'LI') {
                            const taskAttr = li.getAttribute('data-task');
                            const liContent = nodeToMarkdown(li);
                            if (taskAttr === 'checked') {
                                result += '- [x] ' + liContent + '\n';
                            } else if (taskAttr === 'unchecked') {
                                result += '- [ ] ' + liContent + '\n';
                            } else if (tag === 'ol') {
                                result += listIndex + '. ' + liContent + '\n';
                                listIndex++;
                            } else {
                                result += '- ' + liContent + '\n';
                            }
                        }
                    }
                    result += '\n';
                    break;
                case 'table':
                    result += tableToMarkdown(child) + '\n';
                    break;
                case 'div':
                    // iOS contentEditable inserts <div><br></div> for blank lines — treat as paragraph separator
                    if (child.children.length === 1 && child.children[0].tagName === 'BR' && !inner.trim()) {
                        result += '\n';
                    } else if (inner.trim()) {
                        result += inner + '\n';
                    }
                    break;
                default:
                    result += inner;
            }
        }

        return result;
    }

    function tableToMarkdown(table) {
        const rows = table.querySelectorAll('tr');
        if (rows.length === 0) return '';

        let md = '\n';
        rows.forEach((row, rowIndex) => {
            const cells = row.querySelectorAll('th, td');
            const cellTexts = Array.from(cells).map(c => c.textContent.trim());
            md += '| ' + cellTexts.join(' | ') + ' |\n';

            if (rowIndex === 0) {
                md += '| ' + cellTexts.map(() => '---').join(' | ') + ' |\n';
            }
        });

        return md;
    }

    // =========================================================================
    // Content management
    // =========================================================================

    function setContent(markdown, basePath) {
        currentMarkdown = markdown;
        if (basePath) currentBasePath = basePath;
        editor.innerHTML = markdownToHTML(markdown);
        isDirty = false;
    }

    function getMarkdown() {
        // htmlToMarkdown already normalizes newlines and adds trailing \n
        return htmlToMarkdown(editor.innerHTML);
    }

    // =========================================================================
    // Mode switching (preview / edit)
    // =========================================================================

    function setMode(mode) {
        currentMode = mode;
        if (mode === 'preview') {
            editor.contentEditable = 'false';
            editor.classList.add('preview-mode');
            editor.blur();
        } else {
            editor.contentEditable = 'true';
            editor.classList.remove('preview-mode');
            editor.focus();
        }
    }

    // =========================================================================
    // Format commands
    // =========================================================================

    function applyFormat(format) {
        editor.focus();

        switch (format) {
            case 'bold':
                toggleBold();
                break;
            case 'italic':
                toggleItalic();
                break;
            case 'strikethrough':
                toggleStrikethrough();
                break;
            case 'heading1':
                toggleHeading('h1');
                break;
            case 'heading2':
                toggleHeading('h2');
                break;
            case 'undo':
                document.execCommand('undo', false, null);
                break;
            case 'redo':
                document.execCommand('redo', false, null);
                break;
            case 'heading3':
                document.execCommand('formatBlock', false, 'h3');
                break;
            case 'unorderedList':
                document.execCommand('insertUnorderedList', false, null);
                break;
            case 'orderedList':
                document.execCommand('insertOrderedList', false, null);
                break;
            case 'blockquote':
                toggleBlockquote();
                break;
            case 'code':
                toggleInlineCode();
                break;
            case 'codeBlock':
                toggleCodeBlock();
                break;
            case 'horizontalRule':
                document.execCommand('insertHTML', false, '<hr>');
                break;
            case 'link':
                const url = 'https://';
                document.execCommand('createLink', false, url);
                break;
            case 'paragraph':
                document.execCommand('formatBlock', false, 'p');
                break;
        }

        notifyContentChanged();
    }

    function closestElement(node, tag) {
        const el = node && node.nodeType === 3 ? node.parentElement : node;
        return el ? el.closest(tag) : null;
    }

    // Unwrap an inline element, replacing it with its child nodes
    function unwrapElement(el) {
        const parent = el.parentNode;
        while (el.firstChild) parent.insertBefore(el.firstChild, el);
        parent.removeChild(el);
    }

    // Toggle bold: unwrap <strong>/<b> if inside one, otherwise execCommand
    function toggleBold() {
        const anchor = window.getSelection()?.anchorNode;
        const el = closestElement(anchor, 'strong') || closestElement(anchor, 'b');
        el ? unwrapElement(el) : document.execCommand('bold', false, null);
    }

    // Toggle italic: unwrap <em>/<i> if inside one, otherwise execCommand
    function toggleItalic() {
        const anchor = window.getSelection()?.anchorNode;
        const el = closestElement(anchor, 'em') || closestElement(anchor, 'i');
        el ? unwrapElement(el) : document.execCommand('italic', false, null);
    }

    // Toggle strikethrough: unwrap <del>/<s>/<strike> if inside one, otherwise execCommand
    function toggleStrikethrough() {
        const anchor = window.getSelection()?.anchorNode;
        const el = closestElement(anchor, 'del') || closestElement(anchor, 's')
                 || closestElement(anchor, 'strike');
        el ? unwrapElement(el) : document.execCommand('strikethrough', false, null);
    }

    // Toggle heading: remove if already that heading level, otherwise apply
    function toggleHeading(tag) {
        const sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return;
        const anchor = sel.anchorNode;
        const el = anchor && anchor.nodeType === 3 ? anchor.parentElement : anchor;
        document.execCommand('formatBlock', false,
            (el && el.closest(tag)) ? 'p' : tag);
    }

    // Toggle inline code: wrap selection with <code>, or unwrap if already inside <code>
    function toggleInlineCode() {
        const sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return;

        const anchor = sel.anchorNode;
        const codeEl = closestElement(anchor, 'code');
        const inPre = codeEl && codeEl.closest('pre');

        if (codeEl && !inPre) {
            // Already inline code — unwrap
            const text = codeEl.textContent;
            const textNode = document.createTextNode(text);
            codeEl.parentNode.replaceChild(textNode, codeEl);
            const range = document.createRange();
            range.selectNode(textNode);
            sel.removeAllRanges();
            sel.addRange(range);
        } else {
            const range = sel.getRangeAt(0);
            const text = range.toString();
            document.execCommand('insertHTML', false,
                '<code>' + escapeHtml(text || '\u200B') + '</code>');
        }
    }

    // Toggle code block: insert <pre><code>, or convert back to paragraph if already inside <pre>
    function toggleCodeBlock() {
        const sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return;

        const anchor = sel.anchorNode;
        const preEl = closestElement(anchor, 'pre');

        if (preEl) {
            // Already in a code block — unwrap to paragraph
            const text = preEl.textContent;
            const p = document.createElement('p');
            p.textContent = text || '\u200B';
            preEl.parentNode.replaceChild(p, preEl);
            const range = document.createRange();
            range.selectNodeContents(p);
            range.collapse(false);
            sel.removeAllRanges();
            sel.addRange(range);
        } else {
            const text = sel.getRangeAt(0).toString();
            const html = '<pre><code>' + escapeHtml(text || 'code') + '</code></pre><p><br></p>';
            document.execCommand('insertHTML', false, html);
        }
    }

    // Toggle blockquote: remove if already in blockquote, otherwise apply
    function toggleBlockquote() {
        const sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return;

        const anchor = sel.anchorNode;
        const bqEl = closestElement(anchor, 'blockquote');

        if (bqEl) {
            // Already blockquote — convert back to paragraph
            document.execCommand('formatBlock', false, 'p');
        } else {
            document.execCommand('formatBlock', false, 'blockquote');
        }
    }

    function insertImage(path, alt) {
        const html = '<img src="' + path + '" alt="' + (alt || '') + '"><br>';
        editor.focus();
        document.execCommand('insertHTML', false, html);
        notifyContentChanged();
    }

    // =========================================================================
    // Change tracking
    // =========================================================================

    function notifyContentChanged() {
        isDirty = true;
        sendToNative('contentChanged', {
            markdown: getMarkdown(),
            isDirty: true
        });
    }

    editor.addEventListener('input', function() {
        notifyContentChanged();
    });

    // Handle paste - convert to plain text to avoid messy HTML
    editor.addEventListener('paste', function(e) {
        e.preventDefault();
        const text = e.clipboardData.getData('text/plain');
        document.execCommand('insertText', false, text);
    });

    // Handle Enter key in code blocks
    editor.addEventListener('keydown', function(e) {
        if (e.key === 'Tab') {
            e.preventDefault();
            document.execCommand('insertText', false, '    ');
        }
    });

    // In preview mode, tap anywhere to request edit mode.
    // Exceptions: image taps open full-screen viewer; link taps open the URL.
    editor.addEventListener('click', function(e) {
        if (currentMode === 'preview') {
            // Image tap → full-screen viewer
            const img = e.target.closest('img');
            if (img) {
                e.preventDefault();
                e.stopPropagation();
                const src = img.getAttribute('src') || '';
                if (src) sendToNative('imageClicked', { url: src });
                return;
            }
            const anchor = e.target.closest('a[href]');
            if (anchor) {
                e.preventDefault();
                e.stopPropagation(); // prevent bubble handler from firing a second linkClicked
                const href = anchor.getAttribute('href');
                if (href) {
                    sendToNative('linkClicked', { url: href });
                }
                return;
            }
            sendToNative('modeChangeRequested', { mode: 'edit' });
        }
    }, true); // useCapture to intercept before other handlers

    // Task list checkbox toggle + link navigation
    editor.addEventListener('click', function(e) {
        // Handle task list toggles
        const li = e.target.closest('li[data-task]');
        if (li) {
            const current = li.getAttribute('data-task');
            li.setAttribute('data-task', current === 'checked' ? 'unchecked' : 'checked');
            notifyContentChanged();
            return;
        }

        // Handle link clicks — open via native (contentEditable blocks default navigation)
        const anchor = e.target.closest('a[href]');
        if (anchor) {
            e.preventDefault();
            const href = anchor.getAttribute('href');
            if (href) {
                sendToNative('linkClicked', { url: href });
            }
        }
    });

    // Notify native that editor is ready
    sendToNative('editorReady', {});

})();
