-- Controlled, one-time legacy account import. No Firebase credentials or raw exports
-- are accepted here; an operator must first verify and register the UID link.
create table if not exists public.legacy_identity_links (
  legacy_provider text not null check (legacy_provider = 'firebase'),
  legacy_uid text not null check (length(trim(legacy_uid)) between 1 and 128),
  user_id uuid not null references auth.users(id) on delete restrict,
  verification_method text not null check (verification_method in (
    'dual_account_proof', 'support_verified', 'operator_verified'
  )),
  verified_at timestamptz not null default now(),
  verified_by text not null,
  primary key (legacy_provider, legacy_uid),
  unique (user_id, legacy_provider)
);

create table if not exists public.legacy_account_imports (
  legacy_provider text not null check (legacy_provider = 'firebase'),
  legacy_uid text not null,
  user_id uuid not null references auth.users(id) on delete restrict,
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  imported_at timestamptz not null default now(),
  imported_by uuid not null references auth.users(id) on delete restrict,
  import_summary jsonb not null default '{}'::jsonb,
  primary key (legacy_provider, legacy_uid),
  unique (user_id, legacy_provider)
);

alter table public.legacy_identity_links enable row level security;
alter table public.legacy_account_imports enable row level security;
revoke all on public.legacy_identity_links from public, anon, authenticated;
revoke all on public.legacy_account_imports from public, anon, authenticated;
grant select on public.legacy_account_imports to service_role;
grant select, insert, update, delete on public.legacy_identity_links to service_role;
grant select, insert on public.legacy_account_imports to service_role;

alter table public.life_ledger
  drop constraint if exists life_ledger_reason_check;
alter table public.life_ledger
  add constraint life_ledger_reason_check
  check (reason in (
    'NEW_GAME_DEBIT', 'CHAPTER_COMPLETE_REFUND', 'REGENERATION',
    'ADMIN_ADJUSTMENT', 'LEGACY_IMPORT'
  ));

create or replace function public.import_legacy_firebase_account(
  p_legacy_uid text,
  p_source_sha256 text,
  p_payload jsonb,
  p_imported_by uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_existing public.legacy_account_imports%rowtype;
  v_profile jsonb;
  v_membership jsonb;
  v_gold jsonb;
  v_lives jsonb;
  v_tools jsonb;
  v_chapters jsonb;
  v_collection jsonb;
  v_tier text;
  v_membership_status text;
  v_account_status text;
  v_gold_balance bigint;
  v_life_count integer;
  v_next_regen timestamptz;
  v_code text;
  v_tool_code text;
  v_quantity bigint;
  v_chapter jsonb;
  v_value jsonb;
  v_count integer := 0;
  v_tool_count integer := 0;
begin
  if p_legacy_uid is null or length(trim(p_legacy_uid)) not between 1 and 128
    or p_source_sha256 is null or p_source_sha256 !~ '^[a-f0-9]{64}$'
    or p_payload is null or jsonb_typeof(p_payload) <> 'object'
    or p_imported_by is null then
    raise exception using errcode = '22023', message = 'INVALID_LEGACY_IMPORT';
  end if;

  select user_id into v_user_id
    from public.legacy_identity_links
    where legacy_provider = 'firebase' and legacy_uid = trim(p_legacy_uid);
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'LEGACY_IDENTITY_NOT_VERIFIED';
  end if;

  if not exists (select 1 from auth.users where id = v_user_id)
    or not exists (select 1 from auth.users where id = p_imported_by) then
    raise exception using errcode = '23503', message = 'AUTH_USER_NOT_FOUND';
  end if;

  select * into v_existing
    from public.legacy_account_imports
    where legacy_provider = 'firebase' and legacy_uid = trim(p_legacy_uid)
    for update;
  if found then
    if v_existing.user_id <> v_user_id or v_existing.source_sha256 <> p_source_sha256 then
      raise exception using errcode = '23505', message = 'LEGACY_IMPORT_ALREADY_EXISTS_WITH_DIFFERENT_SOURCE';
    end if;
    return jsonb_build_object(
      'imported', false, 'duplicate', true,
      'userId', v_user_id, 'importedAt', v_existing.imported_at
    );
  end if;

  if exists (
    select 1 from public.legacy_account_imports
    where user_id = v_user_id and legacy_provider = 'firebase'
  ) then
    raise exception using errcode = '23505', message = 'SUPABASE_ACCOUNT_ALREADY_LINKED_TO_LEGACY_IMPORT';
  end if;

  -- Never overwrite an account that has already started using Supabase.
  -- A fresh auth-user trigger creates exactly these empty defaults.
  if not exists (
      select 1 from public.memberships
      where user_id = v_user_id and tier = 'FREE' and status = 'active'
    )
    or not exists (
      select 1 from public.gold_wallets
      where user_id = v_user_id and balance = 0
    )
    or not exists (
      select 1 from public.life_wallets
      where user_id = v_user_id and life_count = 5 and next_regen_at is null
    )
    or (select count(*) from public.tool_inventory
      where user_id = v_user_id and tool_code in ('UNDO','REMOVE','SWAP','DUPLICATE')
        and quantity = 0) <> 4
    or exists (select 1 from public.wallet_ledger where user_id = v_user_id)
    or exists (select 1 from public.life_ledger where user_id = v_user_id)
    or exists (select 1 from public.game_progress where user_id = v_user_id)
    or exists (select 1 from public.creature_collection where user_id = v_user_id)
    or exists (select 1 from public.game_sessions where user_id = v_user_id) then
    raise exception using errcode = '55000', message = 'SUPABASE_ACCOUNT_NOT_PRISTINE_FOR_IMPORT';
  end if;

  v_profile := coalesce(p_payload -> 'profile', '{}'::jsonb);
  v_membership := coalesce(p_payload -> 'membership', '{}'::jsonb);
  v_gold := coalesce(p_payload -> 'gold', '{}'::jsonb);
  v_lives := coalesce(p_payload -> 'lives', '{}'::jsonb);
  v_tools := coalesce(p_payload -> 'tools', '{}'::jsonb);
  v_chapters := coalesce(p_payload -> 'chapters', '[]'::jsonb);
  v_collection := coalesce(p_payload -> 'collection', '[]'::jsonb);

  if jsonb_typeof(v_profile) <> 'object'
    or jsonb_typeof(v_membership) <> 'object'
    or jsonb_typeof(v_gold) <> 'object'
    or jsonb_typeof(v_lives) <> 'object'
    or jsonb_typeof(v_tools) <> 'object'
    or jsonb_typeof(v_chapters) <> 'array'
    or jsonb_typeof(v_collection) <> 'array' then
    raise exception using errcode = '22023', message = 'INVALID_LEGACY_IMPORT_SHAPE';
  end if;

  v_tier := case upper(coalesce(v_membership ->> 'tier', 'FREE'))
    when 'PREMIUM' then 'PREMIUM'
    when 'GOLDEN' then 'GOLDEN'
    else 'FREE'
  end;
  v_membership_status := case
    when coalesce(v_membership ->> 'status', 'active') = 'under_review' then 'under_review'
    when coalesce(v_membership ->> 'status', 'active') = 'revoked' then 'revoked'
    else 'active'
  end;
  v_account_status := case
    when coalesce(v_profile ->> 'accountStatus', 'active') = 'locked' then 'locked'
    when coalesce(v_profile ->> 'accountStatus', 'active') = 'under_review' then 'under_review'
    else 'active'
  end;

  if v_tier in ('PREMIUM', 'GOLDEN') and (
    v_membership ->> 'expiresAt' is not null
    or length(trim(coalesce(v_membership ->> 'approvalReference', ''))) not between 1 and 200
  ) then
    raise exception using errcode = '22023', message = 'LEGACY_MEMBERSHIP_REQUIRES_MANUAL_APPROVAL';
  end if;

  if v_membership ->> 'expiresAt' is not null then
    if (v_membership ->> 'expiresAt')::timestamptz <= now() then
      v_tier := 'FREE';
    end if;
  end if;
  if v_membership_status <> 'active' then v_tier := 'FREE'; end if;

  if (select count(*) from jsonb_object_keys(v_tools) as keys(key)) <> 4
    or exists (select 1 from jsonb_object_keys(v_tools) as keys(key)
      where key not in ('UNDO', 'REMOVE', 'SWAP', 'DUPLICATE')) then
    raise exception using errcode = '22023', message = 'INCOMPLETE_LEGACY_TOOL_INVENTORY';
  end if;

  if coalesce(v_gold ->> 'balance', '') !~ '^(0|[1-9][0-9]*)$'
    or length(v_gold ->> 'balance') > 18 then
    raise exception using errcode = '22023', message = 'INVALID_LEGACY_GOLD_BALANCE';
  end if;
  v_gold_balance := (v_gold ->> 'balance')::bigint;

  if coalesce(v_lives ->> 'count', '') !~ '^[0-5]$' then
    raise exception using errcode = '22023', message = 'INVALID_LEGACY_LIFE_COUNT';
  end if;
  v_life_count := (v_lives ->> 'count')::integer;
  v_next_regen := null;
  if v_life_count < 5 then
    if coalesce(v_lives ->> 'nextRegenAt', '') = '' then
      v_next_regen := now() + interval '40 minutes';
    else
      v_next_regen := (v_lives ->> 'nextRegenAt')::timestamptz;
      if v_next_regen < now() - interval '7 days'
        or v_next_regen > now() + interval '40 minutes' then
        raise exception using errcode = '22023', message = 'INVALID_LEGACY_REGENERATION_TIME';
      end if;
    end if;
  end if;

  update public.profiles set
    display_name = left(regexp_replace(trim(coalesce(v_profile ->> 'playerName', display_name)), '\s+', ' ', 'g'), 40),
    avatar_index = case
      when coalesce(v_profile ->> 'avatarIndex', '') ~ '^\d+$'
        then least(53, (v_profile ->> 'avatarIndex')::integer)
      else avatar_index
    end,
    account_status = v_account_status
    where user_id = v_user_id;

  update public.memberships set
    tier = v_tier,
    status = v_membership_status,
    verified_at = case when v_tier = 'FREE' then null else now() end
    where user_id = v_user_id;

  update public.gold_wallets set balance = v_gold_balance
    where user_id = v_user_id;
  if v_gold_balance > 0 then
    insert into public.wallet_ledger (
      user_id, asset_type, quantity_delta, reason, idempotency_key, metadata
    ) values (
      v_user_id, 'GOLD', v_gold_balance, 'LEGACY_IMPORT',
      'legacy-import:firebase:' || trim(p_legacy_uid) || ':gold',
      jsonb_build_object('sourceSha256', p_source_sha256, 'importedBalance', v_gold_balance)
    ) on conflict (user_id, idempotency_key) do nothing;
  end if;

  for v_code, v_quantity in
    select key, value::text::bigint from jsonb_each_text(v_tools)
  loop
    if v_code not in ('UNDO', 'REMOVE', 'SWAP', 'DUPLICATE')
      or v_quantity < 0 then
      raise exception using errcode = '22023', message = 'INVALID_LEGACY_TOOL_INVENTORY';
    end if;
    update public.tool_inventory
      set quantity = v_quantity
      where user_id = v_user_id and tool_code = v_code;
    if v_quantity > 0 then
      insert into public.wallet_ledger (
        user_id, asset_type, asset_code, quantity_delta, reason,
        idempotency_key, metadata
      ) values (
        v_user_id, 'TOOL', v_code, v_quantity, 'LEGACY_IMPORT',
        'legacy-import:firebase:' || trim(p_legacy_uid) || ':tool:' || v_code,
        jsonb_build_object('sourceSha256', p_source_sha256, 'importedQuantity', v_quantity)
      ) on conflict (user_id, idempotency_key) do nothing;
    end if;
    v_tool_count := v_tool_count + 1;
  end loop;

  update public.life_wallets
    set life_count = v_life_count, next_regen_at = v_next_regen
    where user_id = v_user_id;
  if v_life_count <> 5 then
    insert into public.life_ledger (
      user_id, quantity_delta, reason, idempotency_key, metadata
    ) values (
      v_user_id, case when v_life_count = 0 then -5 else v_life_count - 5 end,
      'LEGACY_IMPORT', 'legacy-import:firebase:' || trim(p_legacy_uid) || ':life',
      jsonb_build_object('sourceSha256', p_source_sha256, 'importedLives', v_life_count,
        'nextRegenAt', v_next_regen)
    ) on conflict (user_id, idempotency_key) do nothing;
  end if;

  for v_chapter in select value from jsonb_array_elements(v_chapters)
  loop
    v_code := v_chapter ->> 'chapterCode';
    if v_code not in ('C1','C2','C3','C4','C5','C6')
      or coalesce(v_chapter ->> 'highestStage','') !~ '^(0|[1-9][0-9]*)$'
      or coalesce(v_chapter ->> 'bestScore','') !~ '^(0|[1-9][0-9]*)$' then
      raise exception using errcode = '22023', message = 'INVALID_LEGACY_CHAPTER_PROGRESS';
    end if;
    if (v_chapter ->> 'highestStage')::integer > case v_code
        when 'C1' then 12 when 'C2' then 13 when 'C3' then 14
        when 'C4' then 15 when 'C5' then 16 else 17 end
      or (v_chapter ->> 'bestScore')::numeric > 9007199254740991 then
      raise exception using errcode = '22023', message = 'LEGACY_CHAPTER_PROGRESS_OUT_OF_RANGE';
    end if;
    insert into public.game_progress (
      user_id, chapter_code, highest_stage, best_score, completed_at
    ) values (
      v_user_id, v_code, (v_chapter ->> 'highestStage')::integer,
      (v_chapter ->> 'bestScore')::bigint,
      null
    ) on conflict (user_id, chapter_code) do update set
      highest_stage = excluded.highest_stage,
      best_score = excluded.best_score,
      completed_at = excluded.completed_at;
    v_count := v_count + 1;
  end loop;

  for v_value in select value from jsonb_array_elements(v_collection)
  loop
    v_code := v_value ->> 'chapterCode';
    if v_code not in ('C1','C2','C3','C4','C5','C6')
      or coalesce(v_value ->> 'creatureValue','') !~ '^(2|4|8|16|32|64|128|256|512|1024|2048|4096|8192|16384|32768|65536|131072)$' then
      raise exception using errcode = '22023', message = 'INVALID_LEGACY_COLLECTION_ENTRY';
    end if;
    if (v_value ->> 'creatureValue')::bigint > case v_code
        when 'C1' then 4096 when 'C2' then 8192 when 'C3' then 16384
        when 'C4' then 32768 when 'C5' then 65536 else 131072 end then
      raise exception using errcode = '22023', message = 'LEGACY_COLLECTION_VALUE_EXCEEDS_CHAPTER_TARGET';
    end if;
    insert into public.creature_collection (user_id, chapter_code, creature_value)
    values (v_user_id, v_code, (v_value ->> 'creatureValue')::bigint)
    on conflict (user_id, chapter_code, creature_value) do nothing;
  end loop;

  insert into public.legacy_account_imports (
    legacy_provider, legacy_uid, user_id, source_sha256, imported_by, import_summary
  ) values (
    'firebase', trim(p_legacy_uid), v_user_id, p_source_sha256, p_imported_by,
    jsonb_build_object('membershipTier', v_tier,
      'membershipApprovalReference', v_membership ->> 'approvalReference',
      'gold', v_gold_balance,
      'lives', v_life_count, 'toolsImported', v_tool_count, 'chaptersImported', v_count,
      'collectionEntries', jsonb_array_length(v_collection))
  );

  return jsonb_build_object(
    'imported', true, 'duplicate', false, 'userId', v_user_id,
    'membershipTier', v_tier, 'gold', v_gold_balance, 'lives', v_life_count,
    'toolsImported', v_tool_count, 'chaptersImported', v_count, 'collectionEntries', jsonb_array_length(v_collection)
  );
end;
$$;

revoke all on function public.import_legacy_firebase_account(text, text, jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.import_legacy_firebase_account(text, text, jsonb, uuid)
  to service_role;
