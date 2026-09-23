-- Run after the scheduled time. :t0 = schedule time minus 2 min, :t1 = plus 30 min (UTC).
select id, received_at, rpc_method, tool_name, auth_ok, outcome, left(user_agent,80) ua
from dwi_poc.invocations order by id;
select w.id, w.test_id, w.title, w.source, w.committed_at, i.received_at as invoked_at,
       (w.test_id = 'CHATGPT-EXIT-001'
        and w.title = 'ChatGPT unattended external write test') as payload_matches
from dwi_poc.writes w left join dwi_poc.invocations i on i.id = w.invocation_id
order by w.id;
