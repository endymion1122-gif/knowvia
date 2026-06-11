import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuthStore } from "../stores/authStore";

export function LoginPage({ isRegister }: { isRegister?: boolean }) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login, register } = useAuthStore();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      if (isRegister) {
        await register(username, password);
      } else {
        await login(username, password);
      }
      navigate("/");
    } catch (err: any) {
      setError(err.message || "操作失败");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex h-screen items-center justify-center bg-[var(--page-bg)]">
      <div className="w-full max-w-md p-10 bg-white rounded-2xl shadow-sm border border-[var(--cool-gray)]">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-semibold text-[var(--deep-indigo)]">知径 Knowvia</h1>
          <p className="text-sm text-[var(--secondary-text)] mt-2">
            {isRegister ? "创建你的研究账户" : "Knowledge Pathway 研究原型"}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-xs font-semibold text-[var(--slate-blue)] mb-1.5">用户名</label>
            <input
              type="text" value={username} onChange={(e) => setUsername(e.target.value)}
              className="w-full px-3 py-2.5 border border-[var(--cool-gray)] rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]"
              placeholder="自定义用户名" required autoFocus
            />
          </div>
          <div>
            <label className="block text-xs font-semibold text-[var(--slate-blue)] mb-1.5">密码</label>
            <input
              type="password" value={password} onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2.5 border border-[var(--cool-gray)] rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[var(--deep-indigo)]"
              placeholder="至少 6 位" required minLength={6}
            />
          </div>

          {error && <p className="text-sm text-red-500">{error}</p>}

          <button
            type="submit" disabled={loading}
            className="w-full py-2.5 bg-[var(--deep-indigo)] text-white rounded-lg text-sm font-semibold hover:opacity-90 disabled:opacity-50 transition-colors"
          >
            {loading ? "处理中..." : isRegister ? "注册" : "登录"}
          </button>
        </form>

        <p className="text-center text-xs text-[var(--tertiary-text)] mt-6">
          {isRegister ? (
            <>已有账户？<a href="/login" className="text-[var(--soft-violet)] hover:underline">登录</a></>
          ) : (
            <>没有账户？<a href="/register" className="text-[var(--soft-violet)] hover:underline">注册</a></>
          )}
        </p>

        <p className="text-center text-[10px] text-[var(--tertiary-text)] mt-4">
          本原型仅用于学术研究。注册即表示同意参与使用数据收集。
        </p>
      </div>
    </div>
  );
}
