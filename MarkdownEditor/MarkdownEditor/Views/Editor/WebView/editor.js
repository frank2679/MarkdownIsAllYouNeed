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
                    setContent(payload.markdown || '');
                    break;
                case 'getContent':
                    sendToNative('contentReady', { markdown: getMarkdown() });
                    break;
                case 'insertImage':
                    insertImage(payload.path, payload.alt || '');
                    break;
                case 'formatText':
                    applyFormat(payload.format);
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

        // Images
        html = html.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<img src="$2" alt="$1">');

        // Links
        html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

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

        // Ordered lists
        html = html.replace(/^\d+\.\s+(.+)$/gm, '<li>$1</li>');

        // Wrap consecutive <li> in <ul>
        html = html.replace(/((?:<li[^>]*>.*<\/li>\n?)+)/g, '<ul>$1</ul>');

        // Merge adjacent blockquotes
        html = html.replace(/<\/blockquote>\n<blockquote>/g, '\n');

        // Tables (must run before paragraph wrapping)
        html = parseTables(html);

        // Paragraphs: wrap remaining text blocks
        html = html.replace(/^(?!<[hupbloitd]|<\/|<hr|<img|<a )(.+)$/gm, '<p>$1</p>');

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
        return nodeToMarkdown(tempDiv).trim();
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
                    result += '[' + inner + '](' + href + ')';
                    break;
                case 'img':
                    const src = child.getAttribute('src') || '';
                    const alt = child.getAttribute('alt') || '';
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
                    result += inner + '\n';
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

    function setContent(markdown) {
        currentMarkdown = markdown;
        editor.innerHTML = markdownToHTML(markdown);
        isDirty = false;
    }

    function getMarkdown() {
        return htmlToMarkdown(editor.innerHTML);
    }

    // =========================================================================
    // Format commands
    // =========================================================================

    function applyFormat(format) {
        editor.focus();

        switch (format) {
            case 'bold':
                document.execCommand('bold', false, null);
                break;
            case 'italic':
                document.execCommand('italic', false, null);
                break;
            case 'strikethrough':
                document.execCommand('strikethrough', false, null);
                break;
            case 'heading1':
                document.execCommand('formatBlock', false, 'h1');
                break;
            case 'heading2':
                document.execCommand('formatBlock', false, 'h2');
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
                document.execCommand('formatBlock', false, 'blockquote');
                break;
            case 'code':
                wrapSelectionWith('`', '`');
                break;
            case 'codeBlock':
                insertCodeBlock();
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

    function wrapSelectionWith(before, after) {
        const sel = window.getSelection();
        if (sel.rangeCount > 0) {
            const range = sel.getRangeAt(0);
            const text = range.toString();
            if (text) {
                document.execCommand('insertHTML', false,
                    '<code>' + escapeHtml(text) + '</code>');
            }
        }
    }

    function insertCodeBlock() {
        const sel = window.getSelection();
        const text = sel.rangeCount > 0 ? sel.getRangeAt(0).toString() : '';
        const html = '<pre><code>' + escapeHtml(text || 'code here') + '</code></pre><p><br></p>';
        document.execCommand('insertHTML', false, html);
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

    // Task list checkbox toggle
    editor.addEventListener('click', function(e) {
        const li = e.target.closest('li[data-task]');
        if (li) {
            const current = li.getAttribute('data-task');
            li.setAttribute('data-task', current === 'checked' ? 'unchecked' : 'checked');
            notifyContentChanged();
        }
    });

    // Notify native that editor is ready
    sendToNative('editorReady', {});

})();
