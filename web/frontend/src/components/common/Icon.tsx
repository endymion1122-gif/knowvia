/** Simple inline SVG icons — 20px, currentColor, stroke-based */

interface IconProps { name: string; className?: string; size?: number }

export function Icon({ name, className = "", size = 20 }: IconProps) {
  const s = { width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  const cn = `flex-shrink-0 ${className}`;

  switch (name) {
    case "home": return <svg {...s} className={cn}><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>;
    case "path": return <svg {...s} className={cn}><circle cx="6" cy="6" r="2"/><circle cx="18" cy="8" r="2"/><circle cx="12" cy="18" r="2"/><path d="M7.5 7.5 10.5 16"/><path d="M16.5 8.5 13.5 16"/><path d="M8 6.5C10 10 11 11 12 14"/></svg>;
    case "library": return <svg {...s} className={cn}><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/><line x1="8" y1="7" x2="16" y2="7"/><line x1="8" y1="11" x2="14" y2="11"/></svg>;
    case "cards": return <svg {...s} className={cn}><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="8" y="14" width="7" height="7" rx="1"/></svg>;
    case "recall": return <svg {...s} className={cn}><path d="M12 2a3 3 0 0 0-3 3v1a6 6 0 0 0-5 5.5V14h16v-2.5A6 6 0 0 0 15 6V5a3 3 0 0 0-3-3z"/><path d="M9 18c.5 2 2 3 3 3s2.5-1 3-3"/><circle cx="12" cy="12" r="1"/></svg>;
    case "settings": return <svg {...s} className={cn}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>;
    case "graph": return <svg {...s} className={cn}><circle cx="5" cy="5" r="1.5"/><circle cx="12" cy="5" r="1.5"/><circle cx="19" cy="5" r="1.5"/><circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/><circle cx="12" cy="19" r="1.5"/><line x1="6.3" y1="6" x2="10.8" y2="11.5"/><line x1="13" y1="6" x2="18" y2="11.5"/><line x1="6.3" y1="13" x2="10.8" y2="12.5"/></svg>;
    case "ai": return <svg {...s} className={cn}><rect x="3" y="3" width="18" height="18" rx="3"/><path d="M8 12h8M12 8v8"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/><circle cx="18" cy="6" r="1" fill="currentColor" stroke="none"/><circle cx="6" cy="18" r="1" fill="currentColor" stroke="none"/></svg>;
    case "search": return <svg {...s} className={cn}><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>;
    default: return <svg {...s} className={cn}><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>;
  }
}
