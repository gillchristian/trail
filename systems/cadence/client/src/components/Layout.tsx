import type { ReactNode } from 'react';

export function Layout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col bg-gray-50">
      <div className="mx-auto w-full max-w-4xl flex-1 px-4 py-8">
        {children}
      </div>
      <footer className="py-6 text-center text-sm text-gray-400">
        <p>
          <a href="https://instagram.com/run.the.process" className="hover:text-gray-600 transition-colors">run.the.process</a>
        </p>
        <p>
          <a href="https://gillchristian.xyz" className="hover:text-gray-600 transition-colors">@gillchristian</a> &copy; {new Date().getFullYear()}
        </p>
      </footer>
    </div>
  );
}
