# Ensure shared Codex state is visible in zsh login shells.
if [ -r /etc/profile.d/mickey-codex.sh ]; then
  . /etc/profile.d/mickey-codex.sh
fi
