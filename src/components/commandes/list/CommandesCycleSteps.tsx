import { FileText, ShoppingCart, Truck, CreditCard } from "lucide-react";

const cycleSteps = [
  { label: "Proforma", icon: FileText },
  { label: "Commande", icon: ShoppingCart, active: true },
  { label: "Bon de livraison", icon: Truck },
  { label: "Facture", icon: FileText },
  { label: "Paiement", icon: CreditCard },
];

export function CommandesCycleSteps() {
  return (
    <div className="flex flex-wrap items-center gap-2 rounded-xl border bg-card p-3 shadow-sm">
      {cycleSteps.map((step, i) => (
        <div key={step.label} className="flex items-center gap-2">
          <div
            className={`flex items-center gap-2 rounded-full px-3 py-2 text-sm font-medium ${
              step.active
                ? "bg-primary text-primary-foreground shadow-sm"
                : "bg-muted text-muted-foreground"
            }`}
          >
            <step.icon className="h-4 w-4" />
            <span className="hidden sm:inline">{step.label}</span>
          </div>
          {i < cycleSteps.length - 1 && (
            <span className="hidden h-px w-6 bg-border sm:block" aria-hidden />
          )}
        </div>
      ))}
    </div>
  );
}
