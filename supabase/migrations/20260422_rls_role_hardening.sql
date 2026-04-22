-- ═══════════════════════════════════════════════════════════════
-- Beti — Fase 5: RLS Role Hardening
-- ═══════════════════════════════════════════════════════════════
-- Fecha: 2026-04-22
-- Autor: Equipo Beti
--
-- OBJETIVO:
--   Migrar las 30 políticas RLS existentes del role 'public' al role
--   'authenticated' sin alterar el USING/WITH CHECK (todos ya filtran
--   correctamente por auth.uid() = user_id|id).
--
-- POR QUÉ IMPORTA:
--   El role 'public' incluye usuarios anónimos (token anon de Supabase).
--   Aunque las políticas actuales ya filtran por auth.uid(), permitir el
--   role 'public' deja una capa extra de superficie de ataque innecesaria:
--   un usuario sin login no debería poder ni siquiera EVALUAR las
--   políticas. Restringir a 'authenticated' significa "ni te molestes
--   en intentarlo si no estás logueado".
--
-- ESTRATEGIA:
--   PostgreSQL no tiene "ALTER POLICY ... TO new_role" — hay que DROP +
--   CREATE. Para garantizar atomicidad usamos una transacción única
--   (BEGIN/COMMIT). Si CUALQUIER política falla, rollback completo y la
--   base queda exactamente como estaba.
--
-- IDEMPOTENCIA:
--   Los DROP usan IF EXISTS, así que la migración puede correrse 2 veces
--   sin error. Los CREATE no tienen IF NOT EXISTS (PostgreSQL no lo
--   soporta para policies), pero eso está OK porque el DROP previo
--   garantiza estado limpio.
--
-- VERIFICACIÓN POST-MIGRACIÓN:
--   Al final del archivo hay 2 queries de verificación. Ejecútalos
--   después del COMMIT y confirma que:
--     1. Las 30 políticas ahora tienen role = {authenticated}
--     2. RLS sigue habilitado en las 8 tablas
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- TABLA: budgets
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Usuarios ven sus presupuestos" ON public.budgets;
DROP POLICY IF EXISTS "Usuarios insertan sus presupuestos" ON public.budgets;
DROP POLICY IF EXISTS "Usuarios actualizan sus presupuestos" ON public.budgets;
DROP POLICY IF EXISTS "Usuarios eliminan sus presupuestos" ON public.budgets;

CREATE POLICY "Usuarios ven sus presupuestos"
  ON public.budgets FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Usuarios insertan sus presupuestos"
  ON public.budgets FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios actualizan sus presupuestos"
  ON public.budgets FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios eliminan sus presupuestos"
  ON public.budgets FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- TABLA: categories
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Usuarios ven sus categorías" ON public.categories;
DROP POLICY IF EXISTS "Usuarios insertan sus categorías" ON public.categories;
DROP POLICY IF EXISTS "Usuarios actualizan sus categorías" ON public.categories;
DROP POLICY IF EXISTS "Usuarios eliminan sus categorías" ON public.categories;

CREATE POLICY "Usuarios ven sus categorías"
  ON public.categories FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Usuarios insertan sus categorías"
  ON public.categories FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios actualizan sus categorías"
  ON public.categories FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios eliminan sus categorías"
  ON public.categories FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- TABLA: credit_cards
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Usuarios ven sus tarjetas" ON public.credit_cards;
DROP POLICY IF EXISTS "Usuarios insertan sus tarjetas" ON public.credit_cards;
DROP POLICY IF EXISTS "Usuarios actualizan sus tarjetas" ON public.credit_cards;
DROP POLICY IF EXISTS "Usuarios eliminan sus tarjetas" ON public.credit_cards;

CREATE POLICY "Usuarios ven sus tarjetas"
  ON public.credit_cards FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Usuarios insertan sus tarjetas"
  ON public.credit_cards FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios actualizan sus tarjetas"
  ON public.credit_cards FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios eliminan sus tarjetas"
  ON public.credit_cards FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- TABLA: credits
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Usuarios ven sus créditos" ON public.credits;
DROP POLICY IF EXISTS "Usuarios insertan sus créditos" ON public.credits;
DROP POLICY IF EXISTS "Usuarios actualizan sus créditos" ON public.credits;
DROP POLICY IF EXISTS "Usuarios eliminan sus créditos" ON public.credits;

CREATE POLICY "Usuarios ven sus créditos"
  ON public.credits FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Usuarios insertan sus créditos"
  ON public.credits FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios actualizan sus créditos"
  ON public.credits FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios eliminan sus créditos"
  ON public.credits FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- TABLA: goals
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Usuarios ven sus metas" ON public.goals;
DROP POLICY IF EXISTS "Usuarios insertan sus metas" ON public.goals;
DROP POLICY IF EXISTS "Usuarios actualizan sus metas" ON public.goals;
DROP POLICY IF EXISTS "Usuarios eliminan sus metas" ON public.goals;

CREATE POLICY "Usuarios ven sus metas"
  ON public.goals FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Usuarios insertan sus metas"
  ON public.goals FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios actualizan sus metas"
  ON public.goals FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios eliminan sus metas"
  ON public.goals FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- TABLA: health_snapshots
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Usuarios ven sus snapshots" ON public.health_snapshots;
DROP POLICY IF EXISTS "Usuarios insertan sus snapshots" ON public.health_snapshots;
DROP POLICY IF EXISTS "Usuarios actualizan sus snapshots" ON public.health_snapshots;
DROP POLICY IF EXISTS "Usuarios eliminan sus snapshots" ON public.health_snapshots;

CREATE POLICY "Usuarios ven sus snapshots"
  ON public.health_snapshots FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Usuarios insertan sus snapshots"
  ON public.health_snapshots FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios actualizan sus snapshots"
  ON public.health_snapshots FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios eliminan sus snapshots"
  ON public.health_snapshots FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- TABLA: profiles
-- Nota: solo SELECT y UPDATE. INSERT lo hace el trigger
-- on_auth_user_created (función SECURITY DEFINER que bypassa RLS).
-- DELETE no se permite intencionalmente — los profiles solo se
-- eliminan vía cascade desde auth.users.
-- Filtro especial: usa 'id' (no 'user_id') porque profiles.id
-- ES el auth.uid() del usuario (PK = FK a auth.users).
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Usuarios ven su propio perfil" ON public.profiles;
DROP POLICY IF EXISTS "Usuarios actualizan su propio perfil" ON public.profiles;

CREATE POLICY "Usuarios ven su propio perfil"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Usuarios actualizan su propio perfil"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ─────────────────────────────────────────────────────────────
-- TABLA: transactions
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Usuarios ven sus transacciones" ON public.transactions;
DROP POLICY IF EXISTS "Usuarios insertan sus transacciones" ON public.transactions;
DROP POLICY IF EXISTS "Usuarios actualizan sus transacciones" ON public.transactions;
DROP POLICY IF EXISTS "Usuarios eliminan sus transacciones" ON public.transactions;

CREATE POLICY "Usuarios ven sus transacciones"
  ON public.transactions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Usuarios insertan sus transacciones"
  ON public.transactions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios actualizan sus transacciones"
  ON public.transactions FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuarios eliminan sus transacciones"
  ON public.transactions FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

COMMIT;

-- ═══════════════════════════════════════════════════════════════
-- VERIFICACIÓN POST-MIGRACIÓN
-- ═══════════════════════════════════════════════════════════════
-- Ejecuta estos queries DESPUÉS del COMMIT y confirma:
--   • Query A: TODAS las filas deben tener roles = {authenticated}
--             (cero filas con {public})
--   • Query B: Las 8 tablas deben mantener rls_enabled = true
-- ═══════════════════════════════════════════════════════════════

-- Query A: Verificar roles
-- SELECT
--   tablename,
--   policyname,
--   roles,
--   CASE
--     WHEN roles = '{authenticated}' THEN '✅ OK'
--     WHEN roles = '{public}' THEN '❌ AÚN PUBLIC'
--     ELSE '⚠️  ROLE INESPERADO: ' || roles::text
--   END AS status
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;

-- Query B: Verificar RLS sigue activo
-- SELECT tablename, rowsecurity AS rls_enabled
-- FROM pg_tables
-- WHERE schemaname = 'public'
--   AND tablename IN (
--     'profiles', 'transactions', 'categories', 'credit_cards',
--     'credits', 'budgets', 'goals', 'health_snapshots'
--   )
-- ORDER BY tablename;