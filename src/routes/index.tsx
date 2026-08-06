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
      <p className="text-orange-600 font-medium">Validation différée des commandes active</p>
      <div className="mt-8 max-w-2xl text-left text-sm text-slate-600 bg-slate-50 p-6 rounded-lg border border-slate-200">
        <h2 className="text-lg font-bold text-slate-900 mb-4">Objectif</h2>
        <p className="mb-4">Améliorer l'ergonomie et la cohérence de l'ERP en normalisant l'affichage des dates et le comportement des champs de saisie.</p>
        
        <h3 className="font-bold text-slate-900 mb-2">1. Standardisation des dates</h3>
        <p className="mb-4">Toutes les dates utilisent désormais le format <strong>JJ/MM/AAAA</strong> (Jour / Mois / Année) partout dans le système (Interfaces, Tableaux, PDF, Exports).</p>
        
        <h3 className="font-bold text-slate-900 mb-2">2. Champs de saisie numériques</h3>
        <p className="mb-4">Les champs numériques (Quantité, Prix, Remise, etc.) sont désormais <strong>vides par défaut</strong> au lieu d'afficher 0, évitant les erreurs de saisie courantes.</p>
        
        <h3 className="font-bold text-slate-900 mb-2">3. Workflow de validation intelligent</h3>
        <p>Pour les utilisateurs habilités, la création d'une commande propose désormais le <strong>choix</strong> entre mise en attente et validation immédiate. Toutes les opérations (stock, compta) ne sont déclenchées qu'après validation explicite.</p>
      </div>
    </div>
  );
}

