# dotfiles

These dotfiles configure a number of applications such as the Fish shell, Kitty, Ghostty, tuios and other utilities. The main shell used throughout the configuration is **fish** with the [starship](https://starship.rs) prompt.

Below are quick start instructions for setting up a brand new machine. The steps are separated for macOS and Linux but they share similar requirements.

If you prefer an automated approach, run the provided `install.sh` script with
either `mac` or `linux` as an argument to install all dependencies and link the
configs automatically:

```bash
./install.sh mac   # or "linux"
```

---

## macOS Setup

1. **Install Xcode command line tools**
   ```bash
   xcode-select --install
   ```

2. **Install Homebrew** – the package manager used by these configs.
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.profile
   eval "$(/opt/homebrew/bin/brew shellenv)"
   ```

3. **Install required packages**
   ```bash
   brew install git fish starship tuios neovim stow ripgrep jq fzf yazi lazydocker
   brew install asmvik/formulae/yabai asmvik/formulae/skhd FelixKratz/formulae/sketchybar
   brew install --cask kitty ghostty
   brew install --cask font-meslo-lg-nerd-font font-caskaydia-cove-nerd-font
   ```

4. **Set fish as the default shell**
   ```bash
   sudo sh -c 'echo /opt/homebrew/bin/fish >> /etc/shells'
   chsh -s /opt/homebrew/bin/fish
   ```

5. **Clone these dotfiles**
   ```bash
   git clone https://github.com/your-user/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

6. **Link the configurations using stow**
   ```bash
   stow --target=$HOME fish kitty nvim tuios ghostty
   stow --target=$HOME sketchybar yabai skhd
   ```
   Run `stow` for any other application directories you want to link.

---

## Linux Setup (Debian/Ubuntu based)

1. **Update the system and install basic tools**
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y git curl fish starship neovim stow ripgrep
   ```
   tuios has no apt package. `./install.sh linux` installs a pinned, checksum-verified release; to do it by hand, follow `install_tuios_linux` in `install.sh`.

2. **Install terminal emulators** (optional)
   ```bash
   sudo apt install -y kitty
   ```
   Ghostty may be installed from its release page if desired.

3. **Install Nerd Fonts**
   ```bash
   mkdir -p ~/.local/share/fonts
   cd ~/.local/share/fonts
   curl -L -o Meslo.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip
   curl -L -o CaskaydiaCove.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CaskaydiaCove.zip
   unzip Meslo.zip && unzip CaskaydiaCove.zip
   fc-cache -fv
   ```

4. **Set fish as the default shell**
   ```bash
   echo $(which fish) | sudo tee -a /etc/shells
   chsh -s $(which fish)
   ```

5. **Clone these dotfiles**
   ```bash
   git clone https://github.com/your-user/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

6. **Use stow to create symlinks**
   ```bash
   stow --target=$HOME fish kitty nvim tuios
   ```
   Add or remove directories from the command as needed for your setup.

---

Once everything is installed you can launch a new terminal and fish along with starship will be active. Applications like Kitty or Ghostty will automatically pick up the configuration from `~/.config` once the files are linked.

---

## Pi coding agent

Pi's config lives in `pi/` and is linked into `~/.pi` (auth, sessions and installed packages stay local). The `dotfiles-sync` extension keeps machines in step: when Pi starts it fast-forwards this repo, and when Pi quits it commits and pushes changes under `pi/` (only on `main`, never other files, blocked if anything looks like a secret).

**New machine:** `./install.sh` runs `scripts/setup-pi.sh` for you.

**Machine that already has these dotfiles:**

```bash
git -C ~/dotfiles pull
~/dotfiles/scripts/setup-pi.sh   # needs git, stow, jq; safe to re-run
```

Existing `~/.pi/agent/settings.json`, `vision.json` and `~/.pi/acp.json` are kept as `*.pre-dotfiles`. Restart Pi afterwards. Until the config is linked, new fish shells print a reminder.

Set `PI_DOTFILES_SYNC=0` to turn syncing off on a machine. Problems (pull not a fast-forward, a blocked commit) show as `dotfiles ⚠` in Pi's status line with a message.
