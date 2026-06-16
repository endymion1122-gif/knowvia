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
    } catch (err: any) {
      setError(err.message || "操作失败");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex bg-[var(--page-bg)]">
      {/* Left: Brand Panel */}
      <div className="hidden lg:flex w-[480px] flex-shrink-0 bg-gradient-to-br from-[var(--deep-indigo)] via-[#373D99] to-[var(--soft-violet)] text-white flex-col justify-between p-12 relative overflow-hidden">
        {/* Decorative circles */}
        <div className="absolute top-[-120px] right-[-80px] w-[400px] h-[400px] rounded-full bg-white/4" />
        <div className="absolute bottom-[-60px] left-[-60px] w-[250px] h-[250px] rounded-full bg-white/5" />
        <div className="absolute top-[40%] right-[20%] w-[180px] h-[180px] rounded-full bg-white/3" />

        <div className="relative z-10">
          <div className="text-3xl font-bold tracking-tight mb-2">知径 Knowvia</div>
          <div className="text-sm text-white/70 leading-relaxed">
            把资料变成可理解、可追溯、<br />可复习、可输出的知识路径
          </div>
        </div>

        <div className="relative z-10 space-y-6 text-sm text-white/50 leading-relaxed">
          <div className="flex items-start gap-3">
            <span className="text-lg mt-0.5 opacity-80">◈</span>
            <span>AI 帮你选择重点、建立连接、<br />追溯证据、形成结构</span>
          </div>
          <div className="flex items-start gap-3">
            <span className="text-lg mt-0.5 opacity-80">🧠</span>
            <span>通过主动回忆和输出迁移，<br />让知识真正留下来</span>
          </div>
          <div className="flex items-start gap-3">
            <span className="text-lg mt-0.5 opacity-80">🔗</span>
            <span>从单篇阅读到知识体系，<br />构建你的个人 Knowledge Pathway</span>
          </div>
        </div>
      </div>

      {/* Right: Login Form */}
      <div className="flex-1 flex items-center justify-center p-8">
        <div className="w-full max-w-[400px]">
          {/* Mobile brand header */}
          <div className="lg:hidden text-center mb-10">
            <div className="text-2xl font-bold text-[var(--deep-indigo)] tracking-tight">知径 Knowvia</div>
            <p className="text-sm text-[var(--secondary-text)] mt-2">Knowledge Pathway 研究原型</p>
          </div>

          <div className="bg-white rounded-2xl shadow-[var(--shadow-card)] border border-[var(--border-subtle)] p-8">
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-[var(--primary-text)] tracking-tight">
                {isRegister ? "创建账户" : "欢迎回来"}
              </h2>
              <p className="text-sm text-[var(--tertiary-text)] mt-1.5">
                {isRegister ? "开始构建你的知识路径" : "登录以继续你的学习之旅"}
              </p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label className="block text-xs font-medium text-[var(--secondary-text)] mb-1.5 ml-0.5">
                  用户名
                </label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full h-11 px-4 bg-[var(--page-bg)] border border-[var(--cool-gray)] rounded-xl text-sm placeholder:text-[var(--placeholder-text)] focus:outline-none focus:ring-2 focus:ring-[var(--soft-violet)]/30 focus:border-[var(--soft-violet)] transition-all"
                  placeholder="你的用户名"
                  required
                  autoFocus
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-[var(--secondary-text)] mb-1.5 ml-0.5">
                  密码
                </label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full h-11 px-4 bg-[var(--page-bg)] border border-[var(--cool-gray)] rounded-xl text-sm placeholder:text-[var(--placeholder-text)] focus:outline-none focus:ring-2 focus:ring-[var(--soft-violet)]/30 focus:border-[var(--soft-violet)] transition-all"
                  placeholder="至少 6 位字符"
                  required
                  minLength={6}
                />
              </div>

              {error && (
                <div className="bg-[var(--pale-rose)] text-[var(--danger-red)] text-xs px-4 py-2.5 rounded-xl flex items-center gap-2">
                  <span>⚠</span> {error}
                </div>
              )}

              <button
                type="submit"
                disabled={loading}
                className="w-full h-11 bg-[var(--deep-indigo)] hover:bg-[var(--deep-indigo-hover)] text-white rounded-xl text-sm font-semibold transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed shadow-[var(--shadow-sm)] hover:shadow-[var(--shadow-md)] active:scale-[0.98]"
              >
                {loading ? (
                  <span className="flex items-center justify-center gap-2">
                    <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    处理中...
                  </span>
                ) : isRegister ? "创建账户" : "登录"}
              </button>
            </form>

            <div className="mt-6 pt-5 border-t border-[var(--border-subtle)] text-center">
              <p className="text-sm text-[var(--tertiary-text)]">
                {isRegister ? "已有账户？" : "还没有账户？"}
                <a
                  href={isRegister ? "/login" : "/register"}
                  className="ml-1 text-[var(--soft-violet)] hover:text-[var(--deep-indigo)] font-medium transition-colors"
                >
                  {isRegister ? "登录" : "创建账户"}
                </a>
              </p>
            </div>
          </div>

          <p className="text-center text-[11px] text-[var(--tertiary-text)] mt-6 leading-relaxed">
            研究原型 · 本地优先 · AI 支持<br />
            注册即表示同意参与使用数据收集
          </p>
        </div>
      </div>
    </div>
  );
}
