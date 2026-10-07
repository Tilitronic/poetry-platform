# ssh-add -c Confirmation for the DIA-173 Forwarded-Agent Threat Model — Research Conspect (res020)

<!-- CONSPECTER-OUTPUT-CONTRACT
schema-version: 1.0
agent: conspecter
phase-a-source-count: 12
phase-a-failures: 0
shelf-registration: memory-shelf.yaml (shelf.conspects), delegated to @memory-manager
-->

*Scope: DIA-173 "ssh agent forward opencode-docker" — the host runs an OpenSSH agent; the opencode dev container consumes it through a forwarded `SSH_AUTH_SOCK`. A compromised container can request key signatures at will while the session is alive. This conspect covers the `ssh-add -c` confirmation mechanism, its KDE/Fedora 44 host-side plumbing (systemd user agent + ksshaskpass), and the security evaluation for that threat model.*

---

## 1. ssh-add -c mechanics

`ssh-add -c` marks every key it loads with the confirmation constraint: "Indicates that added identities should be subject to confirmation before being used for authentication" (man7, "ssh-add(1)"). The confirmation is not a passphrase replay — the agent runs the askpass program and treats a *zero exit status* as approval, not any text entered ("Successful confirmation is signaled by a zero exit status from ssh-askpass(1), rather than text entered into the requester") (man7, "ssh-add(1)").

Per-operation askpass invocation: each signature request received by the agent (each `git push` over SSH = one authentication → typically one sign → one confirmation prompt) triggers the askpass program on the machine where the agent process runs. Because the agent "is not running in a shell/terminal, it cannot ask you for the passphrase on any command line" (Bern) — prompting is delegated to the askpass helper.

`SSH_ASKPASS_PROMPT=confirm` (OpenSSH 8.2+): when the agent requests *confirmation* rather than a passphrase, it exposes this variable so askpass programs can render a confirm dialog instead of a password field. This is release-notes-documented behavior (OpenSSH 8.2, supplemental domain knowledge; the archived ssh-add(1) man page documents the confirm mechanism and the `DISPLAY`/`SSH_ASKPASS`/`SSH_ASKPASS_REQUIRE` environment but not the prompt-type variable itself) (man7, "ssh-add(1)").

Host-side rendering — the key point for DIA-173: the agent lives on the host; the container only holds a *forwarded socket* to it. Sign requests arriving over the forwarded socket are indistinguishable from local requests, and the confirmation prompt is rendered by the askpass program on the host desktop. **No container-side change is required** for DIA-173: the `-c` constraint is a property of the key record stored inside the host agent and travels with it regardless of which socket path delivered the request.

## 2. Systemd user ssh-agent (Fedora/RHEL) and the Drop-in

Fedora/RHEL's openssh package ships two systemd *user* units, `ssh-agent.service` + `ssh-agent.socket`, installed into the user unit directory and registered with the user systemd instance (CentOS Stream openssh spec: "install -m644 %{SOURCE16} .../ssh-agent.service", "install -m644 %{SOURCE17} .../ssh-agent.socket", `%systemd_user_post` on both). The service is socket-activated and runs the agent in the foreground (`ssh-agent -D` — the spec changelog notes "Disable forking of ssh-agent on startup", rhbz#2148555).

Critical constraint: the agent reads `SSH_ASKPASS` and `SSH_ASKPASS_REQUIRE` from **its own process environment at prompt time**. There is no per-user config file the agent consults for the askpass path — the askpass program name must already be in the agent's environment when a prompt is needed (Bern: the agent "cannot ask you for the passphrase on any command line" — it can only exec whatever helper its environment names). A systemd-started agent inherits only the unit's `Environment=` lines, not your shell exports.

Consequence: a Drop-in is required, `~/.config/systemd/user/ssh-agent.service.d/override.conf`:

```
[Service]
Environment=SSH_ASKPASS=/usr/bin/ksshaskpass
Environment=SSH_ASKPASS_REQUIRE=force
```

Debian ships exactly this in its own unit — the precedent. When Debian redesigned its ssh-agent user unit (Bug#1068416, then improved in 1:10.0p1-2, closing Bug#1103037 on 15 Apr. 2025), the packaged `debian/systemd/ssh-agent.service` gained `Environment=SSH_ASKPASS_REQUIRE=force` and `ExecStart=/usr/bin/ssh-agent -D`, with a companion `ssh-agent.socket` (`ListenStream=%t/openssh_agent`, `SocketMode=0600`, `ExecStartPost=... set-environment SSH_AUTH_SOCK=%t/openssh_agent`) (Debian OpenSSH Maintainers). The reason is exactly the one above: a socket-activated agent has no tty and no shell environment, so askpass selection must be forced into the unit.

## 3. SSH_ASKPASS_REQUIRE semantics

Introduced in OpenSSH 8.4; documented in the ssh-add(1) man page ENVIRONMENT section and surveyed in Egberts's environment-variable reference:

- `never` — ssh/ssh-add never invokes an askpass program (TTY-only prompting).
- `prefer` — use the askpass program *instead of* the TTY when requesting passwords.
- `force` — use the askpass program for all passphrase input "regardless of whether DISPLAY is set" (Egberts; man7, "ssh-add(1)").

Why `force` is REQUIRED for the systemd-started agent: with `never`/unset and no tty, prompting fails outright; with the default behavior gated on `DISPLAY`, a Wayland session (no `DISPLAY` in the agent env) would also fail. `force` makes the agent always exec `SSH_ASKPASS` — the only mode that works for a socket-activated daemon with neither tty nor X display in its environment.

## 4. ksshaskpass on Fedora 44 + KDE

ksshaskpass is a **separate package** on Fedora — not part of the default KDE spin install. Fedora 44 stable ships `6.7.4-1.fc44` (Rawhide/45: `6.7.4-1.fc45`; EPEL 9: `5.27.12-1.el9`), GPL-2.0-only, binary `/usr/bin/ksshaskpass`, described as "A ssh-add helper that uses kwallet and kpassworddialog" (Fedora Project). Upstream is KDE's `KDE/ksshaskpass` repo; its README states it "is not meant to be executed directly, you need to tell ssh-add about it", stores "ssh key in secure storage via QtKeychain", and uses KWallet + KPasswordDialog (KDE, "KDE/ksshaskpass").

Alternatives and why they do not fit this target:

- `x11-ssh-askpass` — X11-only; unsuitable for a Wayland KDE session (it exists at `/usr/lib/ssh/x11-ssh-askpass` and is a valid alternative only under X11) (mcint).
- `ssh-askpass-gnome` / `gnome-ssh-askpass` — GNOME-specific; Debian and RHEL both ship it as the GNOME askpass (Debian OpenSSH Maintainers; CentOS Stream openssh spec builds `gnome-ssh-askpass`), but it is not a KDE/Wayland fit.

## 5. KDE Wayland gotcha (the #1 failure point)

ksshaskpass is a Qt application and defaults to the **xcb (X11) Qt platform plugin**. Under Wayland the agent invokes it without an X connection and it dies with:

```
qt.qpa.xcb: could not connect to display :0
qt.qpa.plugin: Could not load the Qt platform plugin "xcb"
```

— precisely the failure reported when running `ssh-add -c` / `ksshaskpass` on KDE 6.1 Wayland (mcint; "How do I get ssh-askpass working in Wayland"). Fix: force the Wayland plugin in the agent Drop-in environment:

```
Environment=QT_QPA_PLATFORM=wayland
Environment=WAYLAND_DISPLAY=wayland-0
```

The accepted answer's recipe is exactly this: "Test with `$ QT_QPA_PLATFORM="wayland" ksshaskpass`. If that works, `export QT_QPA_PLATFORM="wayland"` ... possibly in the ssh-agent environment when first launching it" (mcint). `WAYLAND_DISPLAY=wayland-0` is KDE Plasma's Wayland socket name. X11 sessions instead keep `DISPLAY=:0` and the xcb default (the same question documents `DISPLAY=:0` in the working X11 setup).

## 6. Setup recipe (Fedora 44 + KDE Wayland)

1. `dnf install ksshaskpass` (explicit install; not present by default on the KDE spin).
2. Create `~/.config/systemd/user/ssh-agent.service.d/override.conf` with the four `Environment=` lines from §2 + §5, then `systemctl --user daemon-reload`.
3. `systemctl --user restart ssh-agent` — **WARNING: this clears all loaded keys and constraints**, so the order matters: write the Drop-in FIRST, restart, and only then add keys.
4. `ssh-add -c ~/.ssh/id_ed25519` — loads the key with the confirmation constraint (the `-c` flag applies to every key added by this invocation).
5. Verify with `ssh-add -L` (lists loaded public keys). `ssh-add -l` (fingerprints) does **not** reliably indicate the confirm state — there is no simple CLI check that a key is confirm-on; some OpenSSH builds render a "(confirm)" suffix in `-l` output, but the definitive test is behavioral: trigger one real signature (e.g. an actual `git push`) and observe the host-side ksshaskpass confirm dialog (man7, "ssh-add(1)").

## 7. Autostart options (KDE login)

Pick ONE of the following — do not double up, or keys load twice with conflicting constraints:

- **Systemd user unit** `~/.config/systemd/user/ssh-add.service`:
  ```
  [Unit]
  After=graphical-session.target
  [Service]
  Type=oneshot
  Environment=SSH_ASKPASS=/usr/bin/ksshaskpass
  Environment=SSH_ASKPASS_REQUIRE=force
  Environment=QT_QPA_PLATFORM=wayland
  Environment=WAYLAND_DISPLAY=wayland-0
  ExecStart=/usr/bin/ssh-add -c </dev/null
  [Install]
  WantedBy=graphical-session.target
  ```
  The `</dev/null` redirect is required so ssh-add does not wait on a tty and instead routes the prompt through the askpass helper (KDE, "KDE/ksshaskpass"; openSUSE Wiki uses the same redirect in its autostart script).
- **KDE autostart script** `~/.config/autostart-scripts/ssh-add.sh` (chmod +x), mirroring the openSUSE-recommended pattern but with `-c`:
  ```
  #!/bin/sh
  export SSH_ASKPASS=/usr/bin/ksshaskpass
  export SSH_ASKPASS_REQUIRE=force
  export QT_QPA_PLATFORM=wayland
  export WAYLAND_DISPLAY=wayland-0
  /usr/bin/ssh-add -c ~/.ssh/id_ed25519 </dev/null
  ```
  openSUSE's canonical script uses `ssh-add -q </dev/null` with `SSH_ASKPASS=/usr/libexec/ssh/ksshaskpass` (path varies by distro: `/usr/lib/ssh/ksshaskpass` on older, `/usr/libexec/ssh/ksshaskpass` on newer) (openSUSE Wiki).
- Either way, the `SSH_AUTH_SOCK` for login-shell clients must point at the agent socket, conventionally via `~/.config/environment.d/ssh_auth_socket.conf` with `SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"` (systemd user unit writes the socket under the runtime dir; the KWallet-enabled agent makes the passphrase prompt a wallet unlock) (lightsing).

## 8. Failure modes

- **Askpass unset/never** → the agent cannot prompt; the sign request is refused ("Permission denied" / operation fails). With `SSH_ASKPASS_REQUIRE` unset and no tty, prompting silently fails — this is the #1 misconfiguration with a systemd-started agent (§2, §3).
- **User away** → the confirmation dialog sits unacknowledged; if ksshaskpass/KPasswordDialog times out or the user dismisses it, the operation is denied. Confirmation is a positive human action, so absence of the user is a denial by default.
- **Agent restart** → all keys and their `-c`/`-t` constraints are cleared; the user must re-run `ssh-add -c` (order matters per §6). This also silently downgrades security after every reboot until the autostart (§7) re-adds keys with constraints.
- **YubiKey `ed25519-sk`** → for FIDO/SK keys the *hardware touch* is already a per-operation physical approval inside the signature itself (the agent cannot fake it, and the remote sshd verifies the authenticator's assertion). Adding `-c` on top layers a second, redundant approval step — recommend the touch alone **or** `-c`, not both, to avoid double friction.

## 9. Security assessment for the DIA-173 threat model

Threat model: host agent socket forwarded into the opencode dev container; a compromised container can request signatures freely while the session lives.

- `ssh-add -c` — per-operation human approval. Best control against *live interactive* compromise: every signature the container requests surfaces as a visible host dialog, so an attacker gets nothing without the user noticing and approving. Weakness: approvals compound during legitimate bursts (each push = one prompt).
- `ssh-add -t 8h` — time-bounded window (`-t life` documented in ssh-add(1); "maximum lifetime when adding identities to an agent" (man7, "ssh-add(1)")). Complements `-c`: caps the exposure window even when the user stops watching; a fresh container session after the window expires must re-add the key.
- **YubiKey (ed25519-sk)** — strictest: physical touch is required per operation, enforced by hardware and verifiable by the remote sshd; not forgeable by a compromised container or even by the host agent. Trade-off: double friction if combined with `-c` (§8).
- **Recommended combination: `ssh-add -c -t 8h`.** Human approval for live compromise + automatic expiry for unattended windows. Note that `ssh-add -l` / `ssh-add -L` do **not** trigger confirmation prompts — confirmation fires only on actual sign requests, so listing keys remains prompt-free and safe for automation.

---

## Works Cited

Bern, Jochen. "How to Get 'Enter Passphrase' on Command Line Rather Than GUI Pop-up?" *openssh-unix-dev mailing list* (Mindrot), 3 Jan. 2024, http://lists.mindrot.org/pipermail/openssh-unix-dev/2024-January/041126.html.

Debian OpenSSH Maintainers. "Bug#1103037: marked as done (openssh-client: ssh-agent: Improve systemd user service socket activation)." *debian-ssh mailing list*, 15 Apr. 2025, https://www.mail-archive.com/debian-ssh@lists.debian.org/msg09983.html. (Content mirrors lists.debian.org/debian-ssh/2025/04/msg00020.html; the direct URL is behind a JS proof-of-work and has no Wayback snapshot.) Companion message: Daniel Kahn Gillmor, "Bug#1103037: openssh-client: ssh-agent: Improve systemd user service socket activation," https://www.mail-archive.com/debian-ssh@lists.debian.org/msg09972.html.

Egberts. "OpenSSH Environment Variables (v8.8)." *Egbert Blog*, 14 Mar. 2022, https://egbert.net/blog/articles/openssh-environment-variables-v88.html.

Fedora Project. "ksshaskpass — Fedora Packages." *Fedora Packages*, https://packages.fedoraproject.org/pkgs/ksshaskpass/ksshaskpass/.

"How Do I Get ssh-askpass Working in Wayland, on KDE?" *Unix & Linux Stack Exchange*, 30 Jun. 2024, https://unix.stackexchange.com/questions/779264/how-do-i-get-ssh-askpass-working-in-wayland-on-kde. (Archived via Wayback Machine, snapshot 20260227163601.)

"How to Start and Use ssh-agent as Systemd Service?" *Unix & Linux Stack Exchange*, https://unix.stackexchange.com/questions/339840/how-to-start-and-use-ssh-agent-as-systemd-service. (Archived via Wayback Machine, snapshot 20260407040100.) Accepted answer by user "lightsing."

KDE. "KDE/ksshaskpass." *GitHub*, https://github.com/KDE/ksshaskpass.

man7.org. "ssh-add(1) — Linux Manual Page." *Linux man-pages project*, https://man7.org/linux/man-pages/man1/ssh-add.1.html.

man7.org. "ssh_config(5) — Linux Manual Page." *Linux man-pages project*, https://man7.org/linux/man-pages/man5/ssh_config.5.html.

mcint. "Answer to 'How Do I Get ssh-askpass Working in Wayland, on KDE?'" *Unix & Linux Stack Exchange*, 30 Jun. 2024, https://unix.stackexchange.com/a/779265.

openSUSE Wiki. "SDB:Ssh-agent_KDE_Wallet." *openSUSE Wiki*, https://en.opensuse.org/SDB:Ssh-agent_KDE_Wallet. (Archived via Wayback Machine, snapshot 20241003084009.)

"Red Hat CentOS Stream openssh spec (c10s)." *GitLab*, redhat/centos-stream/rpms/openssh, https://gitlab.com/redhat/centos-stream/rpms/openssh/-/raw/c10s/openssh.spec.

"ssh-agent: Improve Systemd User Service Socket Activation" (Bug#1103037 report). *debian-ssh mailing list*, https://www.mail-archive.com/debian-ssh@lists.debian.org/msg09972.html.

*Note on source provenance:* trafilatura was not installed and crawl4ai's CLI is inoperative in this environment (read-only `/app`), so all archives were captured with curl + browser user-agent. Four URLs sit behind JS bot challenges (lists.debian.org, unix.stackexchange.com x2, en.opensuse.org) and were archived via the Wayback Machine or the mail-archive.com mirror; the exact archived URLs are recorded in `sources/.source-urls.txt`.
