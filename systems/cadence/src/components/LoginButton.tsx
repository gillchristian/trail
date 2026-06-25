export function LoginButton({ onClick }: { onClick: () => void }) {
  return (
    <div className="flex min-h-[60vh] items-center justify-center">
      <button
        onClick={onClick}
        className="rounded-lg bg-orange-500 px-6 py-3 text-lg font-semibold text-white hover:bg-orange-600 transition-colors"
      >
        Connect with Strava
      </button>
    </div>
  );
}
