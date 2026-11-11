-- Transaction-level Supabase database tests for Life debit, Restart and chapter refund.
-- Run with: supabase test db
begin;

do $$
declare
  v_user uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789001';
  v_user_rollback uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789002';
  v_game uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789101';
  v_replacement uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789102';
  v_rollback_game uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789201';
  v_request uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789301';
  v_restart_request uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789302';
  v_rollback_request uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789303';
  v_abandon_event uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789401';
  v_rollback_event uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789402';
  v_finish_event uuid := 'd5a7e9f0-1b2c-4d3e-8f50-123456789501';
  v_tiles jsonb := '[2,null,null,null,null,null,null,null,null,null,null,null,null,null,null,2]'::jsonb;
  v_abandon jsonb := '{"reason":"PLAYER_ABANDONED","score":0,"highestValue":4,"toolUsage":{}}'::jsonb;
  v_finish jsonb := '{"score":0,"highestValue":4096,"eventCount":0,"toolPenaltyTotal":0,"toolUsage":{}}'::jsonb;
  v_result jsonb;
  v_lives integer;
  v_count integer;
  v_failed boolean;
begin
  -- Auth user trigger creates profile, membership and wallets.
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_user, 'authenticated', 'authenticated', 'db-lifecycle-test@example.invalid',
    '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

  update public.life_wallets
    set life_count = 1, next_regen_at = now() + interval '40 minutes'
    where user_id = v_user;

  -- First new game costs exactly one Life.
  v_result := public.start_game_session(v_user, v_request, v_game, 'C1', null, v_tiles, true);
  select life_count into v_lives from public.life_wallets where user_id = v_user;
  if v_lives <> 0 then raise exception 'FAIL: first game should debit one Life (got %)', v_lives; end if;
  select count(*) into v_count from public.life_ledger
    where user_id = v_user and game_id = v_game and reason = 'NEW_GAME_DEBIT';
  if v_count <> 1 then raise exception 'FAIL: expected exactly one initial debit, got %', v_count; end if;

  -- Restart is free and atomically settles old session + creates replacement.
  v_result := public.restart_game_session(v_user, v_restart_request, v_replacement, 'C1',
    v_game, v_tiles, v_abandon_event, v_abandon);
  select life_count into v_lives from public.life_wallets where user_id = v_user;
  if v_lives <> 0 then raise exception 'FAIL: Restart charged another Life (got %)', v_lives; end if;
  if (select state from public.game_sessions where game_id = v_game) <> 'ABANDONED'
    then raise exception 'FAIL: old session was not abandoned'; end if;
  if (select state from public.game_sessions where game_id = v_replacement) <> 'ACTIVE'
    then raise exception 'FAIL: replacement session not active'; end if;
  if (select life_debit_ledger_id from public.game_sessions where game_id = v_replacement)
    is distinct from (select id from public.life_ledger where game_id = v_game and reason = 'NEW_GAME_DEBIT')
    then raise exception 'FAIL: original Life debit reference was not carried'; end if;

  -- Exact same request is idempotent: no extra session, event or Life change.
  v_result := public.restart_game_session(v_user, v_restart_request, v_replacement, 'C1',
    v_game, v_tiles, v_abandon_event, v_abandon);
  if coalesce((v_result -> 'started' ->> 'duplicate')::boolean, false) is not true
    then raise exception 'FAIL: repeated Restart was not reported as duplicate'; end if;
  select count(*) into v_count from public.game_sessions where user_id = v_user;
  if v_count <> 2 then raise exception 'FAIL: duplicate Restart created another session'; end if;
  select count(*) into v_count from public.life_ledger
    where user_id = v_user and reason = 'NEW_GAME_DEBIT';
  if v_count <> 1 then raise exception 'FAIL: duplicate Restart created another Life debit'; end if;

  -- Same idempotency key with a different board must be rejected before settlement.
  v_failed := false;
  begin
    perform public.restart_game_session(v_user, v_restart_request, v_replacement, 'C1',
      v_game, '[4,null,null,null,null,null,null,null,null,null,null,null,null,null,null,2]'::jsonb,
      v_abandon_event, v_abandon);
  exception when unique_violation then v_failed := true;
  end;
  if not v_failed then raise exception 'FAIL: mismatched retry payload was accepted'; end if;

  -- Completion refunds the original debit once. A full wallet remains capped at five.
  update public.life_wallets set life_count = 5, next_regen_at = null where user_id = v_user;
  v_result := public.finish_game_chapter(v_user, v_replacement, v_finish_event, v_finish);
  select life_count into v_lives from public.life_wallets where user_id = v_user;
  if v_lives <> 5 then raise exception 'FAIL: chapter refund exceeded cap or reduced full wallet (got %)', v_lives; end if;
  select count(*) into v_count from public.life_ledger
    where user_id = v_user and game_id = v_game and reason = 'CHAPTER_COMPLETE_REFUND';
  if v_count <> 1 then raise exception 'FAIL: expected exactly one completion refund, got %', v_count; end if;

  -- Same completion event returns the stored result; a new event cannot refund again.
  v_result := public.finish_game_chapter(v_user, v_replacement, v_finish_event, v_finish);
  select count(*) into v_count from public.life_ledger
    where user_id = v_user and reason = 'CHAPTER_COMPLETE_REFUND';
  if v_count <> 1 then raise exception 'FAIL: duplicate completion refunded twice'; end if;
  v_failed := false;
  begin
    perform public.finish_game_chapter(v_user, v_replacement,
      'd5a7e9f0-1b2c-4d3e-8f50-123456789502',
      '{"score":0,"highestValue":4096,"eventCount":0,"toolPenaltyTotal":0,"toolUsage":{}}'::jsonb);
  exception when object_not_in_prerequisite_state then v_failed := true;
  end;
  if not v_failed then raise exception 'FAIL: second completion event was accepted'; end if;

  -- A failed replacement (locked chapter) rolls back the old-session settlement.
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (v_user_rollback, 'authenticated', 'authenticated', 'db-rollback-test@example.invalid',
    '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
  update public.life_wallets set life_count = 3, next_regen_at = now() + interval '40 minutes'
    where user_id = v_user_rollback;
  perform public.start_game_session(v_user_rollback, v_rollback_request, v_rollback_game,
    'C1', null, v_tiles, true);
  v_failed := false;
  begin
    perform public.restart_game_session(v_user_rollback,
      'd5a7e9f0-1b2c-4d3e-8f50-123456789304',
      'd5a7e9f0-1b2c-4d3e-8f50-123456789202',
      'C2', v_rollback_game, v_tiles, v_rollback_event, v_abandon);
  exception when insufficient_privilege then v_failed := true;
  end;
  if not v_failed then raise exception 'FAIL: restart into locked chapter was accepted'; end if;
  if (select state from public.game_sessions where game_id = v_rollback_game) <> 'ACTIVE'
    then raise exception 'FAIL: failed Restart did not roll back old session state'; end if;
  select count(*) into v_count from public.game_session_events
    where user_id = v_user_rollback and event_id = v_rollback_event;
  if v_count <> 0 then raise exception 'FAIL: failed Restart left an abandon event behind'; end if;
  select life_count into v_lives from public.life_wallets where user_id = v_user_rollback;
  if v_lives <> 2 then raise exception 'FAIL: failed Restart changed Life balance (got %)', v_lives; end if;
end;
$$;

select plan(1);
select pass('Restart, idempotency, Life debit carry-forward, chapter refund cap and rollback verified');
select * from finish();
rollback;
