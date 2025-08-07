import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
// import { Icons } from './shared/icons';

export function cn(...inputs: ClassValue[]) {
	return twMerge(clsx(inputs));
}

// export const getIcon = (iconName?: keyof typeof Icons) => {
// 	return Icons[iconName || 'arrowRight'];
// };

export const browser = ( () => {
  try {
    return import.meta.env.SSR ?? (typeof window !== 'undefined');
  } catch (e) {
    return (typeof window !== 'undefined');
  }
});
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type WithoutChild<T> = T extends { child?: any } ? Omit<T, "child"> : T;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type WithoutChildren<T> = T extends { children?: any } ? Omit<T, "children"> : T;
export type WithoutChildrenOrChild<T> = WithoutChildren<WithoutChild<T>>;
export type WithElementRef<T, U extends HTMLElement = HTMLElement> = T & { ref?: U | null };

// Navigation utility to replace SvelteKit's goto
export function goto(url: string, options?: { replaceState?: boolean }) {
  if (typeof window !== 'undefined') {
    if (options?.replaceState) {
      window.history.replaceState(null, '', url);
    } else {
      window.history.pushState(null, '', url);
    }
    // Dispatch a custom event to notify components of route changes
    window.dispatchEvent(new CustomEvent('navigate', { detail: { url } }));
  }
}

export default {
  cn,
  browser,
  goto,
};
