import { useState, Suspense, lazy, useCallback } from "react";
import { Routes, Route, useNavigate, useLocation } from "react-router-dom";
import { useAuthStore } from "../../stores/authStore";
import { api } from "../../services/api";

// Static import for the home page (eager load)
import { DashboardPage } from "../../pages/DashboardPage";

// Lazy-loaded pages for code splitting
const LibraryPage = lazy(() => import("../../pages/LibraryPage").then(m => ({ default: m.LibraryPage })));
const PathwayPage = lazy(() => import("../../pages/PathwayPage").then(m => ({ default: m.PathwayPage })));
const CardsPage = lazy(() => import("../../pages/CardsPage").then(m => ({ default: m.CardsPage })));
const SettingsPage = lazy(() => import("../../pages/SettingsPage").then(m => ({ default: m.SettingsPage })));
const ReaderPage = lazy(() => import("../../pages/ReaderPage").then(m => ({ default: m.ReaderPage })));
const InitPage = lazy(() => import("../../pages/InitPage").then(m => ({ default: m.InitPage })));
const RecallPage = lazy(() => import("../../pages/RecallPage").then(m => ({ default: m.RecallPage })));

const PageLoader = () => (
  <div className="flex items-center justify-center h-full">
    <div className="text-sm text-[var(--text-tertiary)] animate-pulse">加载中...</div>
  </div>
);

const NAV_ITEMS = [
  { path: "/", label: "首页", icon: "🏠" },
  { path: "/library", label: "资料库", icon: "📚" },
  { path: "/pathways", label: "专题路径", icon: "🔗" },
  { path: "/cards", label: "知识节点", icon: "◈" },
  { path: "/recall", label: "主动回忆", icon: "🧠" },
  { path: "/settings", label: "设置", icon: "⚙" },
];

export function MainLayout() {
  const { user, logout } = useAuthStore();
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const closeSidebar = () => setSidebarOpen(false);

  const sidebarContent = (
    <>
      <div className="px-5 pt-7 pb-5">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl flex items-center justify-center text-white text-xs font-bold"
            style={{ background: "linear-gradient(135deg, #0EC2C7, #3B6CF8)" }}>知</div>
          <div>
            <h1 className="text-sm font-bold text-[var(--text-primary)] tracking-tight leading-none">知径</h1>
            <p className="text-[10px] text-[var(--text-tertiary)] leading-none mt-0.5">Knowvia</p>
          </div>
        </div>
      </div>
      <nav className="flex-1 px-3 space-y-0.5">
        {NAV_ITEMS.map((item) => {
          const active = item.path === "/" ? location.pathname === "/" : location.pathname.startsWith(item.path);
          return (
            <button
              key={item.path}
              onClick={() => { navigate(item.path); closeSidebar(); }}
              className={`w-full text-left px-3 py-2.5 rounded-xl text-[13px] transition-all duration-200 flex items-center gap-3 ${
                active
                  ? "bg-[var(--primary-100)] text-[var(--brand-indigo)] font-semibold"
                  : "text-[var(--text-secondary)] hover:bg-[var(--bg-input)] hover:text-[var(--text-primary)]"
              }`}
            >
              <span className="text-base flex-shrink-0 w-5 text-center">{item.icon}</span>
              <span className="hidden sm:inline truncate">{item.label}</span>
            </button>
          );
        })}
      </nav>
      <div className="p-3 mx-3 mb-3 mt-2 rounded-xl bg-[var(--bg-input)]">
        <div className="flex items-center gap-2.5">
          <div className="w-7 h-7 rounded-full flex items-center justify-center text-white text-[10px] font-bold flex-shrink-0"
            style={{ background: "linear-gradient(135deg, #3B6CF8, #6B4EF8)" }}>
            {(user?.username || "?")[0].toUpperCase()}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-xs font-medium text-[var(--text-primary)] truncate">{user?.username}</p>
          </div>
          <button onClick={logout} className="text-[10px] text-[var(--text-tertiary)] hover:text-[var(--error)] transition-colors flex-shrink-0" title="退出登录">⏻</button>
        </div>
      </div>
    </>
  );

  return (
    <div className="flex h-screen bg-[var(--bg-page)]">
      {/* Desktop sidebar */}
      <aside className="hidden md:flex w-56 flex-shrink-0 bg-[var(--bg-sidebar)] border-r border-[var(--border-light)] flex-col">
        {sidebarContent}
      </aside>

      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div className="absolute inset-0 bg-black/30" onClick={closeSidebar} />
          <aside className="absolute left-0 top-0 bottom-0 w-56 bg-[var(--bg-sidebar)] flex flex-col z-10 shadow-xl">
            {sidebarContent}
          </aside>
        </div>
      )}

      {/* Mobile header */}
      <div className="md:hidden fixed top-0 left-0 right-0 z-40 bg-[var(--bg-sidebar)] border-b border-[var(--border-light)] px-3 py-2 flex items-center gap-3">
        <button onClick={() => setSidebarOpen(true)} className="text-lg">☰</button>
        <h1 className="text-sm font-semibold text-[var(--brand-indigo)]">知径 Knowvia</h1>
      </div>

      <main className="flex-1 overflow-auto pt-10 md:pt-0">
        <Suspense fallback={<PageLoader />}>
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/library" element={<LibraryPage />} />
            <Route path="/pathways" element={<PathwayPage />} />
            <Route path="/pathway/:id" element={<PathwayPage />} />
            <Route path="/init" element={<InitPage />} />
            <Route path="/recall" element={<RecallPage />} />
            <Route path="/cards" element={<CardsPage />} />
            <Route path="/settings" element={<SettingsPage />} />
            <Route path="/reader/:id" element={<ReaderPage />} />
          </Routes>
        </Suspense>
      </main>
    </div>
  );
}
