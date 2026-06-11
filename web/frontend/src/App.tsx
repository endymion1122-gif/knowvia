import { useEffect } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { useAuthStore } from "./stores/authStore";
import { LoginPage } from "./pages/LoginPage";
import { MainLayout } from "./components/layout/MainLayout";

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuthStore();
  if (loading) return (
    <div className="flex h-screen items-center justify-center bg-[var(--page-bg)]">
      <div className="animate-spin h-8 w-8 border-4 border-[var(--deep-indigo)] border-t-transparent rounded-full" />
    </div>
  );
  if (!user) return <Navigate to="/login" />;
  return <>{children}</>;
}

export default function App() {
  const { checkAuth } = useAuthStore();
  useEffect(() => { checkAuth(); }, []);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<LoginPage isRegister />} />
        <Route path="/*" element={
          <ProtectedRoute><MainLayout /></ProtectedRoute>
        } />
      </Routes>
    </BrowserRouter>
  );
}
