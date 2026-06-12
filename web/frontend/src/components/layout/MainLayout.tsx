import { useState, Suspense, lazy } from "react";
import { Routes, Route, useNavigate, useLocation } from "react-router-dom";
import { useAuthStore } from "../../stores/authStore";

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
    <div className="text-sm text-[var(--tertiary-text)] animate-pulse">加载中...</div>
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

  return (
    <div className="flex h-screen bg-[var(--page-bg)]">
      <aside className="w-56 flex-shrink-0 bg-[var(--warm-white)] border-r border-[var(--cool-gray)] flex flex-col">
        <div className="p-5">
          <h1 className="text-lg font-semibold text-[var(--deep-indigo)]">知径 Knowvia</h1>
          <p className="text-[10px] text-[var(--path-teal)] mt-0.5">Knowledge Pathway 研究原型</p>
        </div>

        <nav className="flex-1 px-3 space-y-1">
          {NAV_ITEMS.map((item) => {
            const active = item.path === "/" ? location.pathname === "/" : location.pathname.startsWith(item.path);
            return (
              <button
                key={item.path}
                onClick={() => navigate(item.path)}
                className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors ${
                  active
                    ? "bg-[var(--pale-lavender)] text-[var(--deep-indigo)] font-semibold"
                    : "text-[var(--secondary-text)] hover:bg-[var(--page-bg)]"
                }`}
              >
                <span className="mr-2">{item.icon}</span>
                {item.label}
              </button>
            );
          })}
        </nav>

        <div className="p-4 border-t border-[var(--cool-gray)]">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-[var(--primary-text)]">{user?.username}</span>
            <button onClick={logout} className="text-[10px] text-[var(--tertiary-text)] hover:text-red-500">
              退出
            </button>
          </div>
        </div>
      </aside>

      <main className="flex-1 overflow-auto">
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
