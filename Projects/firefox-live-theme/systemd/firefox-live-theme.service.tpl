[Unit]
Description=Serve the current Omarchy theme to Firefox's live-theme extension (firefox-live-theme project)
# Standalone from Omarchy's own theme-set flow: this only reads a file
# that flow already produces via a user template, so it starts/stops/
# restarts independently of anything in Omarchy itself.
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
ExecStart=__EXEC_PATH__
Restart=on-failure
RestartSec=3

# Defense in depth on top of the server binding 127.0.0.1 only.
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
NoNewPrivileges=true

[Install]
WantedBy=graphical-session.target
