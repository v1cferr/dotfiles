# Android ADB session: audit the phone, then close the door

The steps on the phone that no tool should take for me: turning debugging on, trusting this
computer, and turning it all off again. The audit itself is `android-iac`
([note](../notes/hardware/android-iac.md)).

## The short way: one command

```sh
android-iac audit
```

It finds the wireless debugging port by mDNS (or asks for the one on the phone's screen), pairs
the first time (asking the pairing port and the six digit code, which goes to adb on stdin and is
never printed), connects, runs `doctor`, `inspect` and `diff`, disconnects, and ends with the
reminder for step 3. Its exit code is the diff's. A phone already attached over USB is used as is
and left attached. The steps below are what it does, for when something fails half-way.

## 1. Open the session

Developer options must exist once: Settings, About phone, tap **Build number** seven times.

**Wireless** (the phone and this desk on the home WiFi; the phone sits at `192.168.1.31`):

1. Settings, System, Developer options, **Wireless debugging** on, and trust the network.
2. **Pair device with pairing code**: the screen shows a port and a six digit code.
3. Here:

   ```sh
   adb pair 192.168.1.31:PAIRING_PORT    # asks for the code
   adb connect 192.168.1.31:PORT         # the port on the MAIN Wireless debugging screen
   ```

Pairing happens once per computer; the connect port changes every time the toggle flips.

**USB**: Developer options, **USB debugging** on, plug the cable, unlock the phone and accept the
RSA prompt for this computer. Leave "Always allow" unchecked if the session is a one-off.

## 2. Audit

```sh
android-iac doctor     # must end with no FAIL
android-iac inspect    # the summary; --json for the full report, never saved inside the repo
android-iac diff; echo $?
```

`doctor` compares `ro.product.model` with the spec, and refuses a different phone.

## 3. Close the session

1. Here: `adb disconnect` (wireless) or unplug the cable.
2. On the phone, Developer options: **Revoke USB debugging authorizations**, then turn off
   **Wireless debugging** and **USB debugging**.
3. Optional: turn Developer options off altogether, at the top of that screen.

`android-iac diff` reports the toggles as `manual` during every audit: that line is the reminder
for this step, not a finding to fix while the session is open.
