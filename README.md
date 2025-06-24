# dotfiles

These dotfiles configure a number of applications such as the Fish shell, Kitty, Ghostty, tmux and other utilities. The main shell used throughout the configuration is **fish** with the [starship](https://starship.rs) prompt.

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
   brew install git fish starship tmux neovim stow ripgrep
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
   stow --target=$HOME/.config fish kitty nvim tmux
   ```
   Run `stow` for any other application directories you want to link.

---

## Linux Setup (Debian/Ubuntu based)

1. **Update the system and install basic tools**
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y git curl fish starship tmux neovim stow ripgrep
   ```

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
   stow --target=$HOME/.config fish kitty nvim tmux
   ```
   Add or remove directories from the command as needed for your setup.

---

Once everything is installed you can launch a new terminal and fish along with starship will be active. Applications like Kitty or Ghostty will automatically pick up the configuration from `~/.config` once the files are linked.

