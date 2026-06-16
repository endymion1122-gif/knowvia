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
      isRegister ? await register(username, password) : await login(username, password);
      navigate("/");
    } catch (err: any) { setError(err.message || "操作失败"); }
    finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen flex bg-[var(--bg-page)]">
      {/* Left: Brand panel with gradient */}
      <div className="hidden lg:flex w-[520px] flex-shrink-0 relative overflow-hidden"
        style={{ background: "linear-gradient(160deg, #1B1E3F 0%, #373A78 40%, #7B6BFF 100%)" }}>
        {/* Glow orbs */}
        <div className="absolute top-[-20%] right-[-15%] w-[500px] h-[500px] rounded-full opacity-20"
          style={{ background: "radial-gradient(circle, #21C7C2 0%, transparent 70%)" }} />
        <div className="absolute bottom-[-10%] left-[-10%] w-[350px] h-[350px] rounded-full opacity-15"
          style={{ background: "radial-gradient(circle, #7B6BFF 0%, transparent 70%)" }} />
        <div className="absolute top-[35%] left-[30%] w-[200px] h-[200px] rounded-full opacity-10"
          style={{ background: "radial-gradient(circle, #FFFFFF 0%, transparent 70%)" }} />

        <div className="relative z-10 flex flex-col justify-between p-14 w-full">
          <div>
            <div className="flex items-center gap-3 mb-10">
              <img src="/logo.png" alt="Knowvia" className="w-10 h-10 rounded-xl object-contain bg-white/10 p-1" />
              <div>
                <div className="text-xl font-bold text-white tracking-tight leading-none">知径 Knowvia</div>
                <div className="text-xs text-white/50 mt-1">Knowledge Pathway System</div>
              </div>
            </div>
            <div className="space-y-6">
              <div className="flex items-start gap-4">
                <div className="w-8 h-8 rounded-lg bg-white/10 flex items-center justify-center text-sm flex-shrink-0 mt-0.5">◈</div>
                <p className="text-sm text-white/80 leading-relaxed">AI 提取概念、观点、证据<br />你来做判断、校准和补充</p>
              </div>
              <div className="flex items-start gap-4">
                <div className="w-8 h-8 rounded-lg bg-white/10 flex items-center justify-center text-sm flex-shrink-0 mt-0.5">🔗</div>
                <p className="text-sm text-white/80 leading-relaxed">建立知识之间的关系<br />形成可追溯的知识路径</p>
              </div>
              <div className="flex items-start gap-4">
                <div className="w-8 h-8 rounded-lg bg-white/10 flex items-center justify-center text-sm flex-shrink-0 mt-0.5">🧠</div>
                <p className="text-sm text-white/80 leading-relaxed">主动回忆 + 输出迁移<br />让知识真正内化留存</p>
              </div>
            </div>
          </div>
          <p className="text-xs text-white/30 leading-relaxed">
            Human-in-the-learning-loop<br />
            本地优先 · AI 支持 · 学术研究原型
          </p>
        </div>
      </div>

      {/* Right: Form */}
      <div className="flex-1 flex items-center justify-center p-8">
        <div className="w-full max-w-[400px]">
          <div className="lg:hidden text-center mb-10">
            <div className="flex items-center justify-center gap-3 mb-3">
              <img src="/logo.png" alt="Knowvia" className="w-10 h-10 rounded-xl object-contain" />
            </div>
            <div className="text-xl font-bold text-[var(--brand-indigo)] tracking-tight">知径 Knowvia</div>
            <p className="text-sm text-[var(--text-tertiary)] mt-1">Knowledge Pathway System</p>
          </div>

          <div className="bg-white rounded-2xl shadow-[var(--shadow-lg)] border border-[var(--border-light)] p-10">
            <div className="mb-8">
              <h2 className="text-2xl font-bold text-[var(--text-primary)] tracking-tight">
                {isRegister ? "创建账户" : "欢迎回来"}
              </h2>
              <p className="text-sm text-[var(--text-tertiary)] mt-2">
                {isRegister ? "开始构建你的知识路径" : "登录以继续你的学习之旅"}
              </p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label className="block text-xs font-semibold text-[var(--text-secondary)] mb-2 ml-0.5 tracking-wide uppercase">
                  用户名
                </label>
                <input type="text" value={username} onChange={(e) => setUsername(e.target.value)}
                  className="w-full h-12 px-4 bg-[var(--bg-input)] border-2 border-transparent rounded-xl text-sm placeholder:text-[var(--text-placeholder)] focus:outline-none focus:border-[var(--primary-400)] focus:bg-white transition-all duration-200"
                  placeholder="输入用户名" required autoFocus />
              </div>

              <div>
                <label className="block text-xs font-semibold text-[var(--text-secondary)] mb-2 ml-0.5 tracking-wide uppercase">
                  密码
                </label>
                <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
                  className="w-full h-12 px-4 bg-[var(--bg-input)] border-2 border-transparent rounded-xl text-sm placeholder:text-[var(--text-placeholder)] focus:outline-none focus:border-[var(--primary-400)] focus:bg-white transition-all duration-200"
                  placeholder="至少 6 位字符" required minLength={6} />
              </div>

              {error && (
                <div className="bg-[var(--error-bg)] text-[var(--error)] text-xs px-4 py-3 rounded-xl flex items-center gap-2 font-medium">
                  <span className="text-base">⚠</span> {error}
                </div>
              )}

              <button type="submit" disabled={loading}
                className="w-full h-12 rounded-xl text-sm font-bold text-white transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed relative overflow-hidden"
                style={{ background: "linear-gradient(135deg, #4B4FC4 0%, #7B6BFF 100%)" }}>
                {loading ? (
                  <span className="flex items-center justify-center gap-2">
                    <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    处理中...
                  </span>
                ) : isRegister ? "创建账户" : "登录"}
              </button>
            </form>

            <div className="mt-8 pt-6 border-t border-[var(--border-light)] text-center">
              <p className="text-sm text-[var(--text-tertiary)]">
                {isRegister ? "已有账户？" : "还没有账户？"}
                <a href={isRegister ? "/login" : "/register"}
                  className="ml-1 text-[var(--primary-400)] hover:text-[var(--brand-violet)] font-semibold transition-colors">
                  {isRegister ? "登录" : "创建账户"}
                </a>
              </p>
            </div>
          </div>

          <p className="text-center text-[11px] text-[var(--text-tertiary)] mt-8 leading-relaxed">
            注册即表示同意参与使用数据收集 · 本地优先
          </p>
        </div>
      </div>
    </div>
  );
}
