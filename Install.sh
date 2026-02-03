#!/bin/bash

CI_MODE=false
LOG_FILE=""
for arg in "$@"; do
	case $arg in
	--ci) CI_MODE=true ;;
	esac
done

if [[ "$CI_MODE" == true ]]; then
	LOG_FILE="$HOME/mac-devops-setup/install.log"
	exec > >(tee -a "$LOG_FILE") 2>&1
	echo "=== Install started at $(date) ==="
fi

printf "# Step 1 : Installing Xcode Command Line Tools\n"
if ! xcode-select -p &>/dev/null; then
	if [[ "$CI_MODE" == true ]]; then
		sudo xcode-select --install 2>/dev/null || true
		until xcode-select -p &>/dev/null; do sleep 5; done
	else
		xcode-select --install
	fi
else
	echo "Xcode Command Line Tools already installed"
fi

echo "# Step 2 : Installing Homebrew"
if ! command -v brew &>/dev/null; then
	if [[ "$CI_MODE" == true ]]; then
		NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	else
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
fi

if [[ -f /opt/homebrew/bin/brew ]]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
	if ! grep -q 'brew shellenv' ~/.zprofile 2>/dev/null; then
		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
	fi
elif [[ -f /usr/local/bin/brew ]]; then
	eval "$(/usr/local/bin/brew shellenv)"
fi

brew doctor || true

echo "# Step 3 : Installing Python3"
brew install python
if ! grep -q '/usr/local/opt/python/libexec/bin' ~/.zshrc 2>/dev/null; then
	echo 'export PATH="/usr/local/opt/python/libexec/bin:$PATH"' >>~/.zshrc
fi
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

echo "# Step 4 : Installing Ansible"
brew install ansible

echo "# Step 5 : Installing Git"
brew install git

echo "# Step 6 : Installing Ansible dependency collections"
ansible-galaxy install -r requirements.yml

if [[ "$CI_MODE" == true ]]; then
	echo "# Running ansible setup (CI mode)"
	ANSIBLE_ARGS=(-i inventory)

	if [[ -n "$GITHUB_ACCESS_TOKEN" ]]; then
		ANSIBLE_ARGS+=(-e "GITHUB_ACCESS_TOKEN=${GITHUB_ACCESS_TOKEN}")
	else
		ANSIBLE_ARGS+=(-e "GITHUB_ACCESS_TOKEN=dummy-token-for-ci")
		ANSIBLE_ARGS+=(--skip-tags "requires_github_token")
	fi

	if [[ -n "$ANSIBLE_BECOME_PASSWORD" ]]; then
		echo "$ANSIBLE_BECOME_PASSWORD" >/tmp/.ansible_pass
		ANSIBLE_ARGS+=(--become-password-file /tmp/.ansible_pass)
		trap 'rm -f /tmp/.ansible_pass' EXIT
	fi

	ansible-playbook setup-my-mac.yml "${ANSIBLE_ARGS[@]}"
else
	while true; do
		read -p "Would you like execute the playbook now? (y/n) " yn
		case $yn in
		[Yy]*) break ;;
		[Nn]*)
			printf "\n Execute this command when you are ready:\n  ansible-playbook setup-my-mac.yml -i inventory -K \n"
			exit
			;;
		*) echo "Please answer yes or no." ;;
		esac
	done

	echo "# Running ansible setup"
	ansible-playbook setup-my-mac.yml -i inventory -K
fi

echo "# Step 7: install other tools"

if [[ ! -d ~/.oh-my-zsh ]]; then
	if [[ "$CI_MODE" == true ]]; then
		RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	else
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	fi
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
	git clone --depth=1 https://github.com/romkatv/powerlevel10k "$ZSH_CUSTOM/themes/powerlevel10k"
fi

if [[ ! -d ~/maximum-awesome ]]; then
	git clone --depth=1 https://github.com/flazz/vim-colorschemes /tmp/vim-colorschemes
	mkdir -p ~/maximum-awesome
	mv /tmp/vim-colorschemes/colors ~/maximum-awesome/
	rm -rf /tmp/vim-colorschemes
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
	git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ ! -d ~/.vim/pack/vendor/start/nerdtree ]]; then
	git clone https://github.com/preservim/nerdtree.git ~/.vim/pack/vendor/start/nerdtree
	vim -u NONE -c "helptags ~/.vim/pack/vendor/start/nerdtree/doc" -c q
fi

defaults write .GlobalPreferences com.apple.mouse.scaling -1

if [[ ! -d ~/.sdkman ]]; then
	if [[ "$CI_MODE" == true ]]; then
		curl -s "https://get.sdkman.io?rcupdate=false" | bash
	else
		curl -s "https://get.sdkman.io" | bash
	fi
fi

echo "# Setup complete!"
if [[ -n "$LOG_FILE" ]]; then
	echo "=== Install finished at $(date) ==="
	echo "Full log saved to: $LOG_FILE"
fi
