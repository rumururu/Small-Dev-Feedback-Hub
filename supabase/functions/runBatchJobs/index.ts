import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

serve(async (_req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

  // 1. 테스트 시작 후 12일 경과한 참여 완료 처리 및 신뢰점수 부여(1점) 알림 (배치 전용 함수로 변경)
  const { error: error1 } = await supabase.rpc("complete_test_request_batch");
  if (error1) {
    console.error("Error in complete_test_request_batch:", error1);
  }

  // 2. 테스트 시작 조건이 충족되면 자동으로 시작 처리 (배치 전용 함수로 변경)
  const { error: error2 } = await supabase.rpc("start_test_request_batch");
  if (error2) {
    console.error("Error in start_test_request_batch:", error2);
  }

  // 3. 테스트 기간 중 앱설치 확인이 1일 이상되지 않으면 참여자에게 경고 알림
  const { error: error3 } = await supabase.rpc("warn_unchecked_install_after_1_day");
  if (error3) {
    console.error("Error in warn_unchecked_install_after_1_day:", error3);
  }

  // 4. 테스트 기간 중 앱설치 확인이 3일 이상되지 않으면 참여 실패 처리, 신뢰점수 감점(-1점), 참여자에게 실패 알림
  const { error: error4 } = await supabase.rpc("fail_unchecked_install_after_3_days");
  if (error4) {
    console.error("Error in fail_unchecked_install_after_3_days:", error4);
  }

  // 5. 테스트 요청 등록 후 30일 동안 테스트가 시작되지 않은 경우 요청 및 참여 완료 처리, 참여자 신뢰점수 부여(1점)/요청자 신뢰점수 감점(-1점), 알림
  const { error: error5 } = await supabase.rpc("complete_test_participations_after_30_days");
  if (error5) {
    console.error("Error in complete_test_participations_after_30_days:", error5);
  }

  // 6. 요청자가 참여 요청 후 7일 내에 반응하지 않으면 요청자 신뢰점수 감점(-1점), 알림
  const { error: error6 } = await supabase.rpc("penalize_requester_for_inaction");
  if (error6) {
    console.error("Error in penalize_requester_for_inaction:", error6);
  }

  return new Response("배치 함수 실행 완료", { status: 200 });

});