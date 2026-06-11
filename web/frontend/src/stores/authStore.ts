import { create } from "zustand";
import { api } from "../services/api";
import type { User } from "../types";

interface AuthState {
  user: User | null;
  token: string | null;
  loading: boolean;
  login: (username: string, password: string) => Promise<void>;
  register: (username: string, password: string) => Promise<void>;
  logout: () => void;
  checkAuth: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: localStorage.getItem("token"),
  loading: true,

  login: async (username, password) => {
    const { token, user } = await api.auth.login(username, password);
    localStorage.setItem("token", token);
    set({ token, user });
  },

  register: async (username, password) => {
    const { token, user } = await api.auth.register(username, password);
    localStorage.setItem("token", token);
    set({ token, user });
  },

  logout: () => {
    localStorage.removeItem("token");
    set({ token: null, user: null });
  },

  checkAuth: async () => {
    const token = localStorage.getItem("token");
    if (!token) {
      set({ loading: false });
      return;
    }
    try {
      const { user } = await api.auth.me();
      set({ user, token, loading: false });
    } catch {
      localStorage.removeItem("token");
      set({ token: null, user: null, loading: false });
    }
  },
}));
