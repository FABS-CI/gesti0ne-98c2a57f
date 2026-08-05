import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { useAuth } from "@/hooks/use-auth";

export const Route = createFileRoute("/")({
  component: IndexRedirect,
});

function IndexRedirect() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!isLoading) {
      if (user) {
        navigate({ to: "/dashboard" });
      } else {
        navigate({ to: "/auth" });
      }
    }
  }, [user, isLoading, navigate]);

  return (
    <div className="flex h-screen flex-col items-center justify-center gap-4 bg-white">
      <img src="/fabs-logo.png" alt="Logo" className="h-20 w-auto animate-pulse" />
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-600"></div>
      <p className="text-orange-600 font-medium">Lancement de GESTI-ONE...</p>
    </div>
  );
}


