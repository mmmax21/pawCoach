"""Automated screenshots at integration-test checkpoints; no manual taps."""
import os, re, subprocess, pathlib
root = pathlib.Path(__file__).resolve().parents[3]
out = pathlib.Path(__file__).resolve().parent
p = subprocess.Popen([os.path.expanduser('~/development/flutter/bin/flutter'), 'test',
    'integration_test/m4_astra_carryover_test.dart', '-d', 'emulator-5554'],
    cwd=root/'app', stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
with (out/'carryover.log').open('w') as log:
    for line in p.stdout:
        log.write(line); log.flush()
        m = re.search(r'M4SHOT (\S+)', line)
        if m:
            with (out/(m[1]+'.png')).open('wb') as f:
                subprocess.run([os.path.expanduser('~/Library/Android/sdk/platform-tools/adb'),
                    '-s','emulator-5554','exec-out','screencap','-p'],stdout=f,check=True)
            if m[1] == 'carry_08_care_scheduled':
                adb = os.path.expanduser('~/Library/Android/sdk/platform-tools/adb')
                for name, args in [('care-alarms.txt',['shell','dumpsys','alarm']),
                                   ('care-notifications.txt',['shell','dumpsys','notification']),
                                   ('care-scheduled-prefs.xml',['shell','run-as','com.puppytrainer.puppy_trainer','cat','shared_prefs/scheduled_notifications.xml'])]:
                    with (out/name).open('wb') as f:
                        subprocess.run([adb,'-s','emulator-5554']+args,stdout=f,stderr=f)
            print('captured', m[1], flush=True)
print('exit', p.wait(), flush=True)
raise SystemExit(p.returncode)
