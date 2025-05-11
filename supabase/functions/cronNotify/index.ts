// supabase/functions/cronNotify/index.ts

import { serve } from "https://deno.land/std@0.181.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2?target=deno&no-check";

// 1) Supabase 클라이언트
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

// 2) Batch 호출할 sendFcm 함수 URL
const SEND_FCM_URL = Deno.env.get("FCM_FUNCTION_URL")!;

serve(async (_req) => {
  try {
    // 1) 아직 전송되지 않은 알림 목록 조회
    const { data: notifications, error: fetchErr } = await supabase
      .rpc("get_unsent_notifications");
    if (fetchErr) {
      console.error("알림 조회 오류:", fetchErr);
      return new Response(JSON.stringify({ error: fetchErr.message }), { status: 500 });
    }
    if (!notifications?.length) {
      return new Response(JSON.stringify({ results: [] }), { status: 200 });
    }

    // 2) 페이로드 구성
    const payload = notifications.map((n: any) => ({
      userId: n.user_id,
      title:  n.title,
      body:   n.body,
      notiId: n.noti_id,
      action: n.action,
      data:   n.payload,
    }));

    // 3) sendFcm에 한 번에 전송 요청
    console.log("cronNotify 호출 URL:", SEND_FCM_URL);
    const res = await fetch(SEND_FCM_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    const resultJson = await res.json();

    // 4) 만약 sendFcm 레벨에서 에러가 없으면, response status 따라 자동으로 sent 업데이트됨
    //    (sendFcm 함수 안에서 notiId별 sent=true 처리 로직이 있어야 합니다)

    return new Response(JSON.stringify({ results: resultJson }), {
      status: res.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e: any) {
    console.error("cronNotify 에러:", e);
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});