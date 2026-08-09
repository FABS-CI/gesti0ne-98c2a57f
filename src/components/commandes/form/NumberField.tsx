import { useState } from "react";
import { Controller } from "react-hook-form";
import { Input } from "@/components/ui/input";

/**
 * Champ numérique contrôlé : accepte l'état vide par défaut,
 * évitant les '0' accidentels lors de la création de documents.
 */
export function NumberField({
  control,
  name,
  integer = false,
  min,
  max,
  step,
  className,
  inputMode,
  disabled,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  control: any;
  name: string;
  integer?: boolean;
  min?: number;
  max?: number;
  step?: string | number;
  className?: string;
  inputMode?: "numeric" | "decimal";
  disabled?: boolean;
}) {
  return (
    <Controller
      control={control}
      name={name}
      render={({ field }) => {
        // eslint-disable-next-line react-hooks/rules-of-hooks
        const [local, setLocal] = useState<string | null>(field.value === undefined || field.value === null ? "" : null);
        
        // On traite 0, null ou undefined comme une chaîne vide pour l'affichage initial
        const numeric =
          field.value === undefined || field.value === null || Number.isNaN(field.value as number) || field.value === 0
            ? ""
            : String(field.value).replace(".", ",");
            
        const displayed = local ?? numeric;
        
        return (
          <Input
            type="text"
            placeholder=""
            className={cn("text-base md:text-base h-10", className)}
            inputMode={inputMode ?? (integer ? "numeric" : "decimal")}
            pattern={integer ? "[0-9]*" : "[0-9]*[.,]?[0-9]*"}
            value={displayed}
            min={min}
            max={max}
            step={step}
            onChange={(e) => {
              const input = e.target.value;
              const raw = input.replace(",", ".");
              
              if (input === "") {
                setLocal("");
                // On met null ou undefined pour signifier "vide", 
                // mais le schéma Zod s'occupe de la validation finale
                field.onChange(undefined);
                return;
              }
              
              const re = integer ? /^-?\d*$/ : /^-?\d*[.,]?\d*$/;
              if (!re.test(input)) return;
              
              setLocal(input);
              if (/^-?\d+(\.\d+)?$/.test(raw)) {
                const n = integer ? parseInt(raw, 10) : parseFloat(raw);
                if (!Number.isNaN(n)) field.onChange(n);
              }
            }}
            onBlur={() => {
              setLocal(null);
              field.onBlur();
            }}
            ref={field.ref}
            name={field.name}
            className={className}
            disabled={disabled}
          />
        );
      }}
    />
  );
}
