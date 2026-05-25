/* SwiftIPTV Panel - JS compartilhado */

/**
 * Exibe um toast no canto inferior direito.
 * @param {'success'|'error'|'info'} type
 * @param {string} message
 */
function toast(type, message) {
    const container = document.getElementById('toast-container');
    if (!container) { return; }

    const colors = {
        success: 'border-emerald-500/40 bg-emerald-500/10 text-emerald-300',
        error:   'border-rose-500/40 bg-rose-500/10 text-rose-300',
        info:    'border-sky-500/40 bg-sky-500/10 text-sky-300',
    };
    const icons = {
        success: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
        error:   '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
        info:    '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/><circle cx="12" cy="12" r="10"/></svg>',
    };

    const el = document.createElement('div');
    el.className = `toast-item flex items-center gap-2.5 rounded-lg border px-4 py-3 text-sm font-medium shadow-lg backdrop-blur ${colors[type] || colors.info}`;
    el.innerHTML = `${icons[type] || icons.info}<span>${message}</span>`;
    container.appendChild(el);

    // remove com fade
    setTimeout(() => {
        el.classList.add('toast-out');
        setTimeout(() => el.remove(), 300);
    }, 3500);
}
