import type { ReactNode } from "react";

interface CardProps {
  children: ReactNode;
  variant?: "default" | "featured" | "panel";
  className?: string;
  onClick?: () => void;
  padding?: "sm" | "md" | "lg";
}

const paddingMap = { sm: "p-3", md: "p-4", lg: "p-5" };

export function Card({ children, variant = "default", className = "", onClick, padding = "md" }: CardProps) {
  const base = "bg-white rounded-2xl transition-all duration-200";

  const variants: Record<string, string> = {
    default: "border border-[var(--border-default)] shadow-[var(--shadow-card)] hover:shadow-[var(--shadow-floating)]",
    featured: "border border-[#DED8FF] shadow-[var(--shadow-floating)]",
    panel: "border border-[var(--border-default)]",
  };

  return (
    <div
      className={`${base} ${variants[variant]} ${paddingMap[padding]} ${onClick ? "cursor-pointer" : ""} ${className}`}
      onClick={onClick}
      style={variant === "featured"
        ? { background: "linear-gradient(135deg, #F7F4FF 0%, #FFFFFF 72%)" }
        : undefined}
    >
      {children}
    </div>
  );
}

interface StatCardProps {
  label: string;
  value: number | string;
  icon: string;
  variant?: "violet" | "teal" | "indigo";
  onClick?: () => void;
}

export function StatCard({ label, value, icon, variant = "violet", onClick }: StatCardProps) {
  const iconBg = {
    violet: "bg-[var(--primary-100)]",
    teal: "bg-[var(--teal-100)]",
    indigo: "bg-[#EDEFF8]",
  };
  return (
    <div
      onClick={onClick}
      className="bg-white rounded-2xl p-5 border border-[var(--border-default)] shadow-[var(--shadow-card)] hover:shadow-[var(--shadow-floating)] transition-all duration-200 cursor-pointer"
    >
      <div className="flex items-start justify-between mb-3">
        <span className="text-2xl">{icon}</span>
        <span className="text-3xl font-bold text-[var(--text-primary)] tabular-nums">{value}</span>
      </div>
      <p className="text-[13px] font-medium text-[var(--text-secondary)]">{label}</p>
    </div>
  );
}
