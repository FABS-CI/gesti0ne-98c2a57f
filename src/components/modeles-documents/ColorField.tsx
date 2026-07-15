import { Label } from "@/components/ui/label";
import type { RGB } from "@/lib/pdf/pdfConfig";
import { toHex, fromHex } from "@/lib/modeles-documents-helpers";

export function ColorField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: RGB;
  onChange: (c: RGB) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-2">
      <Label className="text-xs">{label}</Label>
      <input
        type="color"
        value={toHex(value)}
        onChange={(e) => onChange(fromHex(e.target.value))}
        className="h-8 w-12 cursor-pointer rounded border bg-transparent"
      />
    </div>
  );
}
