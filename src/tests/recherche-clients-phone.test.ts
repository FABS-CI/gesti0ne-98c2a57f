import { describe, it, expect } from 'vitest';
import { supabase } from '@/integrations/supabase/client';

describe('Recherche Clients par Téléphone (v2.0.2)', () => {
  it('doit normaliser un numéro Ivoirien correctement via la RPC', async () => {
    const { data, error } = await supabase.rpc('normalize_phone', { phone: '+225 07 48 72 47 03' });
    expect(error).toBeNull();
    expect(data).toBe('0748724703');
  });

  it('doit normaliser d\'autres formats', async () => {
    const { data: d1 } = await supabase.rpc('normalize_phone', { phone: '002250748724703' });
    expect(d1).toBe('0748724703');
    
    const { data: d2 } = await supabase.rpc('normalize_phone', { phone: '07 48 72 47 03' });
    expect(d2).toBe('0748724703');

    const { data: d3 } = await supabase.rpc('normalize_phone', { phone: '07-48-72-47-03' });
    expect(d3).toBe('0748724703');
  });
});
