import os, subprocess, pathlib
root=pathlib.Path(__file__).resolve().parents[3]
out=pathlib.Path(__file__).resolve().parent
server=subprocess.Popen([str(root/'server/.venv/bin/uvicorn'),'main:app','--host','0.0.0.0','--port','8779','--log-level','warning'],cwd=root/'server',env={**os.environ,'DB_PATH':'/tmp/astra-m4a-legacy-rerun.sqlite','FAKE_UPSTREAM':'1'},stdout=(out/'legacy-server-rerun.log').open('w'),stderr=subprocess.STDOUT)
try:
 p=subprocess.Popen([os.path.expanduser('~/development/flutter/bin/flutter'),'test','integration_test/m3_ai_coach_test.dart','-d','emulator-5554','--dart-define=AI_BASE_URL=http://10.0.2.2:8779'],cwd=root/'app',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 with (out/'legacy-m3-rerun.log').open('w') as log:
  for line in p.stdout:
   log.write(line);log.flush()
   if '课程内提问：技能页' in line and ' +0:' in line:
    result=subprocess.run([os.path.expanduser('~/Library/Android/sdk/platform-tools/adb'),'-s','emulator-5554','shell','pm','grant','com.puppytrainer.puppy_trainer','android.permission.POST_NOTIFICATIONS'],capture_output=True,text=True)
    log.write(f'ASTRA_PERMISSION rc={result.returncode} {result.stdout}{result.stderr}\n');log.flush()
 raise SystemExit(p.wait())
finally:server.terminate();server.wait()
