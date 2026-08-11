import { describe, it, expect } from 'vitest';
import { supabase } from '@/integrations/supabase/client';

describe('Recherche Clients par Téléphone (v2.0.2)', () => {
  it('doit normaliser un numéro Ivoirien correctement via la RPC', async () => {
    const { data, error } = await supabase.rpc('normalize_phone', { phone: '+225 07 48 72 47 03' });
    if (error) console.error('Normalization error:', error);
    expect(error).toBeNull();
    expect(data).toBe('0748724703');
  });

  it('doit supporter la recherche via search_clients_crm', async () => {
    // search_clients_crm a déjà GRANT TO authenticated
    const { data, error } = await supabase.rpc('search_clients_crm', {
      _filters: { q: '0748724703' }
    });
    if (error) console.error('Search error:', error);
    expect(error).toBeNull();
    expect(data).toBeDefined();
    expect(data.items).toBeDefined();
  });

  it('doit être tolérant aux formats dans search_clients_crm', async () => {
    const { data, error } = await supabase.rpc('search_clients_crm', {
      _filters: { q: '+225 07 48 72 47 03' }
    });
    expect(error).toBeNull();
    expect(data.items).toBeDefined();
  });
});
